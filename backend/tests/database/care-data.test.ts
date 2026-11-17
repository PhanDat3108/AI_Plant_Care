import "dotenv/config";
import { randomUUID } from "node:crypto";
import { beforeAll, afterAll, afterEach, expect, it, vi } from "vitest";
import request from "supertest";
import { createDatabase } from "../../src/config/database.js";
import { readConfig } from "../../src/config/env.js";
import { createApp } from "../../src/app.js";
import { careDataService } from "../../src/services/care-data.js";
import { carePlanner } from "../../src/services/care-planner.js";
import { scheduleService } from "../../src/services/schedules.js";
import {
  createCareProvider,
  type CareIdentity,
  type CareProvider,
} from "../../src/services/gemini-care.js";
import type { CareProposal } from "../../src/services/care-data-schema.js";
import { HttpError } from "../../src/middlewares/errors.js";

const db = createDatabase(process.env.DATABASE_URL!);
const owner = randomUUID(),
  other = randomUUID(),
  reviewer = randomUUID();
const speciesIds: string[] = [];
const now = new Date("2026-11-17T00:00:00Z");
const config = readConfig({
  NODE_ENV: "test",
  DATABASE_URL: process.env.DATABASE_URL,
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_PUBLISHABLE_KEY: "test",
  CARE_AI_MODE: "demo",
  CARE_REVIEWER_IDS: reviewer,
});
const app = createApp(config, db);
const headers = { Authorization: "Bearer test" };
const proposal = (identity: CareIdentity): CareProposal => ({
  scientific_name: identity.scientific_name,
  care: {
    watering_days: 7,
    fertilizing_days: 30,
    water_guide: "Fixture đã kiểm tra điều kiện tưới.",
    fertilizer_guide: "Fixture chỉ bón khi cây đang sinh trưởng.",
    light_guide: null,
    soil_guide: null,
    temperature_guide: null,
  },
  assumptions: ["Fixture kiểm thử"],
  source_ids: [],
});
function provider(
  generate = vi.fn(async (identity: CareIdentity) => proposal(identity)),
): CareProvider {
  return { provider: "gemini", model: "test-model", isMock: false, generate };
}
async function fixture() {
  const id = randomUUID();
  speciesIds.push(id);
  await db.plant_species.create({
    data: { id, scientific_name: "Care fixture " + id, common_name: "Fixture" },
  });
  const plant = await db.plants.create({
    data: {
      owner_id: owner,
      species_id: id,
      nickname: "Test",
      environment: "indoor",
    },
  });
  return { id, plant };
}
function auth(id = owner) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async () =>
      Response.json({ id, user_metadata: { role: "admin", is_admin: true } }),
    ),
  );
}
beforeAll(async () => {
  await db.profiles.createMany({
    data: [owner, other, reviewer].map((id) => ({ id, display_name: "Test" })),
  });
});
afterEach(() => vi.unstubAllGlobals());
afterAll(async () => {
  await db.profiles.deleteMany({
    where: { id: { in: [owner, other, reviewer] } },
  });
  await db.plant_species.deleteMany({ where: { id: { in: speciesIds } } });
  await db.$disconnect();
});
it("stores a shared proposal once, blocks planner until review, then initializes schedules", async () => {
  const { id, plant } = await fixture();
  const p = provider();
  const service = careDataService(db, p, () => now);
  const first = await service.enrichForPlant(owner, plant.id);
  expect(first.cached).toBe(false);
  expect(first.species).toMatchObject({
    care_status: "draft",
    watering_days: null,
  });
  expect(first.draft?.data).toMatchObject({ care: { watering_days: 7 } });
  const another = await db.plants.create({
    data: { owner_id: other, species_id: id, nickname: "Same species" },
  });
  expect((await service.enrichForPlant(other, another.id)).cached).toBe(true);
  expect(p.generate).toHaveBeenCalledTimes(1);
  const planner = carePlanner(db, { forecast: async () => null }, () => now);
  const pending = await planner.sync(owner, plant.id);
  expect(pending.tasks).toHaveLength(0);
  expect(pending.warnings).toContain("CARE_DATA_REVIEW_REQUIRED");
  const approved = await service.review(id, reviewer, {
    action: "approve",
    generation_id: first.draft!.generation_id,
    note: "Đã kiểm tra fixture",
  });
  expect(approved.species).toMatchObject({
    care_status: "verified",
    watering_days: 7,
    fertilizing_days: 30,
    care_model: "test-model",
  });
  expect((await planner.sync(owner, plant.id)).tasks).toHaveLength(2);
  const repeat = await service.enrichForPlant(owner, plant.id);
  expect(repeat.cached).toBe(true);
  expect(p.generate).toHaveBeenCalledTimes(1);
  await expect(
    service.review(id, reviewer, {
      action: "approve",
      generation_id: first.draft!.generation_id,
      note: "retry",
    }),
  ).rejects.toMatchObject({ status: 409 });
});
it("ownership, reviewer permissions and strict bodies are enforced on HTTP routes", async () => {
  const { id, plant } = await fixture();
  const path = `/api/v1/plants/${plant.id}/care-data`;
  await request(app).get(path).expect(401);
  auth(other);
  await request(app).get(path).set(headers).expect(404);
  await request(app)
    .post(path + "/enrich")
    .set(headers)
    .send({})
    .expect(404);
  auth();
  await request(app)
    .post(path + "/enrich")
    .set(headers)
    .send({ force: true })
    .expect(400);
  await request(app)
    .get(`/api/v1/species/${id}/care-data`)
    .set(headers)
    .expect(403);
  await request(app)
    .patch(`/api/v1/species/${id}/care-data/review`)
    .set(headers)
    .send({})
    .expect(403);
  const result = await request(app)
    .post(path + "/enrich")
    .set(headers)
    .send({})
    .expect(200);
  expect(result.body.data.draft.is_mock).toBe(true);
  expect(result.body.data.draft.source_documents).toBeUndefined();
  auth(reviewer);
  await request(app)
    .get(`/api/v1/species/${id}/care-data`)
    .set(headers)
    .expect(200);
  const deny = await request(app)
    .patch(`/api/v1/species/${id}/care-data/review`)
    .set(headers)
    .send({
      action: "approve",
      generation_id: result.body.data.draft.generation_id,
      note: "Cannot approve demo",
    })
    .expect(409);
  expect(deny.body.error.code).toBe("DEMO_CANNOT_BE_APPROVED");
  const unknown = await db.plants.create({
    data: { owner_id: owner, nickname: "Unknown" },
  });
  auth();
  await request(app)
    .post(`/api/v1/plants/${unknown.id}/care-data/enrich`)
    .set(headers)
    .send({})
    .expect(409);
});
it("lease prevents duplicate calls across service instances and recovers stale work", async () => {
  const { id, plant } = await fixture();
  let started!: () => void, finish!: (data: CareProposal) => void;
  const begun = new Promise<void>((resolve) => {
    started = resolve;
  });
  const generation = new Promise<CareProposal>((resolve) => {
    finish = resolve;
  });
  const p = provider(
    vi.fn(async () => {
      started();
      return generation;
    }),
  );
  const s1 = careDataService(db, p, () => now),
    s2 = careDataService(db, p, () => now);
  const first = s1.enrichForPlant(owner, plant.id);
  await begun;
  const concurrent = await s2.enrichForPlant(owner, plant.id);
  expect(concurrent.draft?.status).toBe("generating");
  finish(
    proposal({
      scientific_name: "Care fixture " + id,
      common_name: null,
      sources: [],
    }),
  );
  await first;
  expect(p.generate).toHaveBeenCalledTimes(1);
  await db.species_care_drafts.update({
    where: { species_id: id },
    data: {
      status: "generating",
      started_at: new Date(now.getTime() - 100000),
    },
  });
  const recovered = await careDataService(db, provider(), () => now).generate(
    id,
  );
  expect(recovered.cached).toBe(false);
  expect(recovered.draft?.status).toBe("draft");
});
it("late response cannot overwrite a newer draft or review", async () => {
  const { id } = await fixture();
  let started!: () => void, finish!: (data: CareProposal) => void;
  const begun = new Promise<void>((resolve) => {
    started = resolve;
  });
  const generation = new Promise<CareProposal>((resolve) => {
    finish = resolve;
  });
  const old = careDataService(
    db,
    provider(
      vi.fn(async () => {
        started();
        return generation;
      }),
    ),
    () => now,
  ).generate(id);
  const oldError = expect(old).rejects.toMatchObject({
    code: "CARE_DRAFT_CHANGED",
  });
  await begun;
  const service = careDataService(
    db,
    provider(),
    () => new Date(now.getTime() + 100000),
  );
  const fresh = await service.generate(id);
  await service.review(id, reviewer, {
    action: "approve",
    generation_id: fresh.draft!.generation_id,
    note: "latest",
  });
  finish(
    proposal({
      scientific_name: "Care fixture " + id,
      common_name: null,
      sources: [],
    }),
  );
  await oldError;
  expect((await service.read(id)).draft).toMatchObject({
    generation_id: fresh.draft!.generation_id,
    status: "approved",
  });
});
it("failures preserve verified data and throttle retries; missing key demo is replaced by live", async () => {
  const { id } = await fixture();
  const demo = careDataService(db, createCareProvider(config), () => now);
  const fake = await demo.generate(id);
  const live = careDataService(db, provider(), () => now);
  const actual = await live.generate(id);
  expect(actual.draft?.is_mock).toBe(false);
  expect(actual.draft?.generation_id).not.toBe(fake.draft?.generation_id);
  await live.review(id, reviewer, {
    action: "approve",
    generation_id: actual.draft!.generation_id,
    note: "checked",
  });
  const failingProvider = provider(
    vi.fn(async () => {
      throw new HttpError(503, "AI_RATE_LIMITED", "test");
    }),
  );
  const failed = careDataService(db, failingProvider, () => now);
  await expect(failed.generate(id, { force: true })).rejects.toMatchObject({
    code: "AI_RATE_LIMITED",
  });
  const result = await failed.read(id);
  expect(result.species).toMatchObject({
    care_status: "verified",
    watering_days: 7,
  });
  expect(result.draft).toMatchObject({
    status: "failed",
    error_code: "AI_RATE_LIMITED",
  });
  await failed.generate(id);
  expect(failingProvider.generate).toHaveBeenCalledTimes(1);
  const empty = await fixture();
  await expect(failed.generate(empty.id)).rejects.toMatchObject({
    code: "AI_RATE_LIMITED",
  });
  await failed.generate(empty.id);
  expect(failingProvider.generate).toHaveBeenCalledTimes(2);
});
it("review may edit proposed values, reject refreshes, and preserves existing manual schedules", async () => {
  const { id, plant } = await fixture();
  const service = careDataService(db, provider(), () => now);
  const draft = await service.generate(id, {
    sources: [
      {
        title: "Fixture",
        url: "https://example.org/care",
        excerpt: "Fixture source",
      },
    ],
  });
  await scheduleService(db).save(owner, plant.id, "water", {
    interval_days: 3,
    local_time: "09:00",
    enabled: true,
  });
  const planner = carePlanner(db, { forecast: async () => null });
  expect((await planner.sync(owner, plant.id)).tasks).toHaveLength(1);
  const base = proposal({
    scientific_name: "Care fixture " + id,
    common_name: null,
    sources: [],
  }).care;
  await service.review(id, reviewer, {
    action: "approve",
    generation_id: draft.draft!.generation_id,
    note: "Adjusted fixture",
    care: { ...base, watering_days: 10 },
  });
  expect((await planner.sync(owner, plant.id)).tasks).toHaveLength(2);
  expect(
    (
      await db.care_schedules.findUniqueOrThrow({
        where: { plant_id_kind: { plant_id: plant.id, kind: "water" } },
      })
    ).interval_days,
  ).toBe(3);
  const next = await service.generate(id, { force: true });
  await expect(
    service.review(id, reviewer, {
      action: "approve",
      generation_id: draft.draft!.generation_id,
      note: "stale",
    }),
  ).rejects.toMatchObject({ status: 409 });
  await service.review(id, reviewer, {
    action: "reject",
    generation_id: next.draft!.generation_id,
    note: "Keep existing",
  });
  expect((await service.read(id)).species.watering_days).toBe(10);
  expect((await service.read(id)).draft?.status).toBe("rejected");
});
it("verified nullable intervals stay missing instead of inventing a schedule", async () => {
  const { id, plant } = await fixture();
  const p = provider(
    vi.fn(async (identity: CareIdentity) => ({
      ...proposal(identity),
      care: {
        ...proposal(identity).care,
        watering_days: null,
        fertilizing_days: null,
      },
    })),
  );
  const service = careDataService(db, p);
  const draft = await service.generate(id);
  await service.review(id, reviewer, {
    action: "approve",
    generation_id: draft.draft!.generation_id,
    note: "Guides only",
  });
  const result = await carePlanner(db, { forecast: async () => null }).sync(
    owner,
    plant.id,
  );
  expect(result.tasks).toHaveLength(0);
  expect(result.warnings).toContain("MISSING_WATER_INTERVAL");
  expect(result.warnings).toContain("MISSING_FERTILIZE_INTERVAL");
});

it("HTTP reviewer can approve a real proposal and the planner consumes approved edits", async () => {
  const { id, plant } = await fixture();
  const liveApp = createApp(
    { ...config, CARE_AI_MODE: "live", GEMINI_API_KEY: "fixture-key" },
    db,
  );
  let signedIn = owner;
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string | URL | Request) => {
      if (String(url).startsWith("https://example.supabase.co/"))
        return Response.json({ id: signedIn });
      const data = proposal({
        scientific_name: "Care fixture " + id,
        common_name: null,
        sources: [],
      });
      return Response.json({
        candidates: [
          {
            finishReason: "STOP",
            content: { parts: [{ text: JSON.stringify(data) }] },
          },
        ],
      });
    }),
  );
  const generated = await request(liveApp)
    .post(`/api/v1/plants/${plant.id}/care-data/enrich`)
    .set(headers)
    .send({})
    .expect(200);
  const reviewUrl = `/api/v1/species/${id}/care-data/review`;
  const body = {
    action: "approve",
    generation_id: generated.body.data.draft.generation_id,
    note: "Reviewed fixture",
  };
  await request(liveApp).patch(reviewUrl).set(headers).send(body).expect(403);
  signedIn = reviewer;
  await request(liveApp)
    .patch(reviewUrl)
    .set(headers)
    .send({ ...body, owner_id: owner })
    .expect(400);
  const approved = await request(liveApp)
    .patch(reviewUrl)
    .set(headers)
    .send(body)
    .expect(200);
  expect(approved.body.data.species.care_status).toBe("verified");
  signedIn = owner;
  const tasks = await request(liveApp)
    .post(`/api/v1/plants/${plant.id}/care-plan/sync`)
    .set(headers)
    .send({})
    .expect(200);
  expect(tasks.body.data.tasks).toHaveLength(2);
});
