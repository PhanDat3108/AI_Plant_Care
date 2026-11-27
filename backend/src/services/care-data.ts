import { randomUUID } from "node:crypto";
import { Prisma } from "../generated/prisma/client.js";
import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";
import {
  careDataSchema,
  careProposalSchema,
  referencesSchema,
  sameSpecies,
  type CareProposal,
  type CareReference,
  type ReviewInput,
} from "./care-data-schema.js";
import { carePlanner } from "./care-planner.js";
import { sharedOpenMeteoProvider } from "./weather.js";
import type { CareProvider } from "./gemini-care.js";

const notFound = () =>
  new HttpError(404, "NOT_FOUND", "Không tìm thấy cây hoặc loài cây.");
const conflict = () =>
  new HttpError(
    409,
    "CARE_DRAFT_CHANGED",
    "Bản đề xuất đã thay đổi; tải lại trước khi duyệt.",
  );

export function careDataService(
  db: Database,
  provider: CareProvider,
  clock = () => new Date(),
) {
  const planner = carePlanner(db, sharedOpenMeteoProvider(), clock);
  // Publish real AI output without a human approval step. Never claim human verification.
  async function publishAI(
    tx: Prisma.TransactionClient,
    speciesId: string,
    proposal: CareProposal,
    model: string,
    generatedAt: Date,
    sources: CareReference[],
  ) {
    await tx.plant_species.updateMany({
      where: { id: speciesId, care_status: { not: "verified" } },
      data: {
        ...proposal.care,
        care_status: "ai_suggested",
        care_model: model,
        care_generated_at: generatedAt,
        care_reviewed_at: null,
        care_reviewed_by: null,
        care_source: JSON.stringify({
          provider: "gemini",
          model,
          publication: "automatic",
          source_mode: sources.length
            ? "provided_references"
            : "model_knowledge",
          sources: sources.map(({ title, url }) => ({ title, url })),
          assumptions: proposal.assumptions,
        }),
      },
    });
  }
  async function speciesForPlant(ownerId: string, plantId: string) {
    const plant = await db.plants.findFirst({
      where: { id: plantId, owner_id: ownerId },
      select: { species_id: true },
    });
    if (!plant) throw notFound();
    if (!plant.species_id)
      throw new HttpError(
        409,
        "SPECIES_REQUIRED",
        "Cần xác định và lưu loài cây trước khi bổ sung dữ liệu chăm sóc.",
      );
    return plant.species_id;
  }
  async function read(speciesId: string, reviewer = false) {
    const row = await db.plant_species.findUnique({
      where: { id: speciesId },
      include: { care_draft: true },
    });
    if (!row) throw notFound();
    const { care_draft: draft, care_reviewed_by: reviewedBy, ...species } = row;
    return {
      species,
      ...(reviewer ? { care_reviewed_by: reviewedBy } : {}),
      draft: draft
        ? {
            generation_id: draft.generation_id,
            status: draft.status,
            provider: draft.provider,
            model: draft.model,
            is_mock: draft.is_mock,
            data: draft.data,
            generated_at: draft.generated_at,
            retry_after: draft.retry_after,
            error_code: draft.error_code,
            source_mode: (draft.source_documents as unknown[]).length
              ? "provided_references"
              : "model_knowledge",
            ...(reviewer
              ? {
                  source_documents: draft.source_documents,
                  review_note: draft.review_note,
                  reviewed_by: draft.reviewed_by,
                  reviewed_at: draft.reviewed_at,
                }
              : {}),
          }
        : null,
    };
  }

  async function generate(
    speciesId: string,
    options: { force?: boolean; sources?: CareReference[] } = {},
  ) {
    const now = clock();
    const claim = await db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM plantcare.plant_species WHERE id=${speciesId}::uuid FOR UPDATE`;
      const species = await tx.plant_species.findUnique({
        where: { id: speciesId },
        include: { care_draft: true },
      });
      if (!species) throw notFound();
      const existing = species.care_draft;
      if (
        existing?.status === "generating" &&
        now.getTime() - existing.started_at.getTime() < 90_000
      )
        return null;
      if (!options.force && species.care_status === "verified") return null;
      if (
        !options.force &&
        existing &&
        sameSpecies(existing.scientific_name, species.scientific_name)
      ) {
        // Adding a real key automatically replaces cached demo proposals on the next request.
        const reusable =
          existing.provider === provider.provider &&
          existing.model === provider.model;
        if (
          reusable &&
          ["draft", "approved", "rejected"].includes(existing.status)
        ) {
          // Existing real drafts from the previous workflow become usable on enrich.
          if (
            existing.status === "draft" &&
            !existing.is_mock &&
            species.care_status !== "ai_suggested"
          ) {
            await publishAI(
              tx,
              speciesId,
              careProposalSchema.parse(existing.data),
              existing.model,
              existing.generated_at!,
              referencesSchema.parse(existing.source_documents),
            );
          }
          return null;
        }
        if (
          reusable &&
          existing.status === "failed" &&
          existing.retry_after &&
          existing.retry_after > now
        )
          return null;
      }
      const sources = referencesSchema.parse(
        options.sources ?? existing?.source_documents ?? [],
      );
      const generationId = randomUUID();
      const value = {
        generation_id: generationId,
        scientific_name: species.scientific_name,
        status: "generating",
        provider: provider.provider,
        model: provider.model,
        is_mock: provider.isMock,
        source_documents: sources,
        data: Prisma.DbNull,
        started_at: now,
        generated_at: null,
        retry_after: null,
        error_code: null,
        reviewed_at: null,
        reviewed_by: null,
        review_note: null,
      };
      await tx.species_care_drafts.upsert({
        where: { species_id: speciesId },
        create: { species_id: speciesId, ...value },
        update: value,
      });
      return {
        generationId,
        identity: {
          scientific_name: species.scientific_name,
          common_name: species.common_name,
          sources,
        },
      };
    });
    if (!claim) return { ...(await read(speciesId)), cached: true };
    try {
      // External work must not hold a PostgreSQL transaction/row lock.
      const proposal = careProposalSchema.parse(
        await provider.generate(claim.identity),
      );
      if (
        !sameSpecies(proposal.scientific_name, claim.identity.scientific_name)
      )
        throw new HttpError(
          502,
          "AI_INVALID_RESPONSE",
          "Bản đề xuất không đúng loài.",
        );
      await db.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM plantcare.plant_species WHERE id=${speciesId}::uuid FOR UPDATE`;
        const current = await tx.plant_species.findUnique({
          where: { id: speciesId },
        });
        if (
          !current ||
          !sameSpecies(current.scientific_name, claim.identity.scientific_name)
        )
          throw conflict();
        const changed = await tx.species_care_drafts.updateMany({
          where: {
            species_id: speciesId,
            generation_id: claim.generationId,
            status: "generating",
          },
          data: { data: proposal, status: "draft", generated_at: clock() },
        });
        if (!changed.count) throw conflict();
        if (!provider.isMock && provider.provider === "gemini") {
          await publishAI(
            tx,
            speciesId,
            proposal,
            provider.model,
            clock(),
            claim.identity.sources,
          );
        } else {
          // Demo must never replace real canonical care data.
          await tx.plant_species.updateMany({
            where: { id: speciesId, care_status: { in: ["missing", "draft"] } },
            data: { care_status: "draft" },
          });
        }
      });
    } catch (error) {
      const failure =
        error instanceof HttpError
          ? error
          : new HttpError(
              502,
              "AI_INVALID_RESPONSE",
              "Không lưu được bản đề xuất hợp lệ.",
            );
      await db.species_care_drafts.updateMany({
        where: {
          species_id: speciesId,
          generation_id: claim.generationId,
          status: "generating",
        },
        data: {
          status: "failed",
          error_code: failure.code,
          retry_after: new Date(clock().getTime() + 5 * 60_000),
        },
      });
      throw failure;
    }
    return { ...(await read(speciesId)), cached: false };
  }

  async function review(
    speciesId: string,
    reviewerId: string,
    input: ReviewInput,
  ) {
    await db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM plantcare.plant_species WHERE id=${speciesId}::uuid FOR UPDATE`;
      const species = await tx.plant_species.findUnique({
        where: { id: speciesId },
        include: { care_draft: true },
      });
      if (!species) throw notFound();
      const draft = species.care_draft;
      if (
        !draft ||
        draft.generation_id !== input.generation_id ||
        draft.status !== "draft" ||
        !sameSpecies(draft.scientific_name, species.scientific_name)
      )
        throw conflict();
      const now = clock();
      if (input.action === "approve") {
        if (draft.is_mock)
          throw new HttpError(
            409,
            "DEMO_CANNOT_BE_APPROVED",
            "Bản demo không được dùng làm dữ liệu chăm sóc thật.",
          );
        const proposal = careProposalSchema.parse(draft.data);
        const care = careDataSchema.parse(input.care ?? proposal.care);
        if (Object.values(care).every((v) => v === null))
          throw new HttpError(
            400,
            "CARE_DATA_EMPTY",
            "Cần ít nhất một hướng dẫn đã được kiểm tra.",
          );
        const sources = referencesSchema.parse(draft.source_documents);
        await tx.plant_species.update({
          where: { id: speciesId },
          data: {
            ...care,
            care_status: "verified",
            care_model: draft.model,
            care_generated_at: draft.generated_at,
            care_reviewed_at: now,
            care_reviewed_by: reviewerId,
            care_source: JSON.stringify({
              provider: draft.provider,
              model: draft.model,
              source_mode: sources.length
                ? "provided_references"
                : "model_knowledge",
              sources: sources.map(({ title, url }) => ({ title, url })),
              assumptions: proposal.assumptions,
              review_note: input.note,
            }),
          },
        });
      }
      await tx.species_care_drafts.update({
        where: { species_id: speciesId },
        data: {
          status: input.action === "approve" ? "approved" : "rejected",
          reviewed_at: now,
          reviewed_by: reviewerId,
          review_note: input.note,
        },
      });
    });
    return read(speciesId, true);
  }
  return {
    read,
    generate,
    review,
    async readForPlant(ownerId: string, plantId: string) {
      return read(await speciesForPlant(ownerId, plantId));
    },
    async enrichForPlant(ownerId: string, plantId: string) {
      const result = await generate(await speciesForPlant(ownerId, plantId));
      if (!["verified", "ai_suggested"].includes(result.species.care_status)) {
        return { ...result, schedule_sync: "awaiting_care_data" };
      }
      try {
        await planner.sync(ownerId, plantId);
        return { ...result, schedule_sync: "synced" };
      } catch (error) {
        if (error instanceof HttpError && error.status < 500) throw error;
        // The periodic reminder job retries sync independently of enrichment.
        console.warn("CARE_PLAN_SYNC_DEFERRED", plantId);
        return { ...result, schedule_sync: "deferred" };
      }
    },
  };
}
