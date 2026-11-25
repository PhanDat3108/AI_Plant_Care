import { randomUUID } from "node:crypto";
import { z } from "zod";
import type { scansModel } from "../generated/prisma/models/scans.js";
import type { scan_findingsModel } from "../generated/prisma/models/scan_findings.js";
import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";
import type { Config } from "../config/env.js";
import { plantImageStorage, type PlantImageStorage } from "./plant-image-storage.js";

// ─── Types & Constants ────────────────────────────────────────────────────────

export type Scan = scansModel;
export type ScanFinding = scan_findingsModel;

export type ScanResult = Scan & {
  scan_findings: ScanFinding[];
  image_url: string | null;
  isExisting?: boolean;
};

export type ScanListItem = Scan & {
  image_url: string | null;
};

export const SCAN_MODES = ["identify", "diagnose", "both"] as const;
export type ScanMode = (typeof SCAN_MODES)[number];

export const ALLOWED_MIME_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
] as const;
export type AllowedMimeType = (typeof ALLOWED_MIME_TYPES)[number];

export const MIME_TO_EXT: Record<AllowedMimeType, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

export const HEALTH_STATUSES = [
  "healthy",
  "suspected",
  "unknown",
  "not_assessed",
] as const;
export type HealthStatus = (typeof HEALTH_STATUSES)[number];

export interface CreateScanInput {
  mode: string;
  imageBuffer: Buffer;
  mimeType: string;
  request_id?: string | null;
  plant_id?: string | null;
  organ?: string | null;
}

export interface ListScansQuery {
  mode?: string | null;
  plant_id?: string | null;
  limit?: number | null;
}

/** Dữ liệu một finding từ Gemini Vision */
interface GeminiFinding {
  reported_name: string;
  confidence?: number | null;
  symptoms?: string | null;
  possible_cause?: string | null;
  treatment_steps?: string[];
}

/** Dữ liệu trả về từ Gemini Vision */
interface GeminiDiagnoseResult {
  health_status: HealthStatus;
  findings: GeminiFinding[];
}

/** Dữ liệu trả về từ PlantNet API */
interface PlantNetResult {
  scientific_name: string;
  common_name: string | null;
  confidence: number;
}

const translationResponseSchema = z.object({
  vietnamese_name: z.string().trim().max(100).nullable().optional(),
});

// ─── Helper: Dịch tên khoa học sang tiếng Việt qua Gemini ─────────────────────

/**
 * Gọi Gemini API để tra cứu tên tiếng Việt phổ biến của loài cây.
 * Luôn bắt lỗi an toàn và trả về null nếu có sự cố để không làm gián đoạn luồng quét.
 */
export async function translateSpeciesToVietnamese(
  scientificName: string,
  config: Config,
): Promise<string | null> {
  if (!config.GEMINI_API_KEY) {
    return null;
  }

  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(config.GEMINI_MODEL)}:generateContent`;
    const prompt = `Bạn là chuyên gia thực vật học. Hãy cung cấp tên gọi tiếng Việt phổ biến nhất cho loài thực vật có tên khoa học là "${scientificName}".
Trả về DUY NHẤT định dạng JSON: {"vietnamese_name": "Tên tiếng Việt"} hoặc {"vietnamese_name": null} nếu không có tên tiếng Việt phổ biến hoặc không rõ.`;

    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": config.GEMINI_API_KEY,
      },
      signal: AbortSignal.timeout(15_000),
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [{ text: prompt }],
          },
        ],
        generationConfig: {
          response_mime_type: "application/json",
        },
      }),
    });

    if (!res.ok) {
      return null;
    }

    const data = (await res.json()) as {
      candidates?: Array<{
        content?: { parts?: Array<{ text?: string }> };
      }>;
    };

    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) return null;

    const parsed = translationResponseSchema.safeParse(JSON.parse(text));
    if (!parsed.success) return null;

    const vn = parsed.data.vietnamese_name?.trim();
    return vn && vn.length > 0 ? vn : null;
  } catch {
    return null;
  }
}

/**
 * Định dạng tên hiển thị của cây:
 * Trả về `${vietnameseName} (${scientificName})` nếu có vietnameseName, ngược lại trả về `scientificName`.
 */
export function formatSpeciesDisplayName(
  scientificName: string,
  vietnameseName: string | null | undefined,
): string {
  const vn = vietnameseName?.trim();
  const sci = scientificName.trim();
  if (vn && vn.length > 0) {
    return `${vn} (${sci})`;
  }
  return sci;
}

// ─── Helper: Gọi PlantNet API ─────────────────────────────────────────────────

/**
 * Gửi ảnh lên PlantNet để nhận diện loài cây.
 */
export async function callPlantNet(
  imageBuffer: Buffer,
  mimeType: string,
  project: string,
  apiKey: string,
  organ = "auto",
): Promise<PlantNetResult> {
  const url = `https://my-api.plantnet.org/v2/identify/${project}?api-key=${apiKey}&lang=en`;
  const formData = new FormData();
  const blob = new Blob([new Uint8Array(imageBuffer)], { type: mimeType });
  formData.append("images", blob, `plant.${MIME_TO_EXT[mimeType as AllowedMimeType] ?? "jpg"}`);
  formData.append("organs", organ);

  const res = await fetch(url, { method: "POST", body: formData });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new HttpError(
      502,
      "PLANTNET_ERROR",
      `PlantNet API lỗi (${res.status}): ${text.slice(0, 200)}`,
    );
  }

  const json = (await res.json()) as {
    results?: Array<{
      species?: {
        scientificName?: string;
        commonNames?: string[];
      };
      score?: number;
    }>;
  };

  const top = json.results?.[0];
  if (!top?.species?.scientificName) {
    throw new HttpError(
      422,
      "PLANTNET_NO_RESULT",
      "PlantNet không nhận ra loài cây trong ảnh này.",
    );
  }

  return {
    scientific_name: top.species.scientificName,
    common_name: top.species.commonNames?.[0] ?? null,
    confidence: top.score ?? 0,
  };
}

// ─── Helper: Gọi Gemini Vision API ───────────────────────────────────────────

/**
 * Gửi ảnh lên Gemini Vision để chẩn đoán sức khỏe cây.
 */
export async function callGeminiVision(
  imageBuffer: Buffer,
  mimeType: string,
  apiKey: string,
  model: string,
  speciesName?: string | null,
): Promise<GeminiDiagnoseResult> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const base64 = imageBuffer.toString("base64");

  const speciesHint = speciesName
    ? `Cây này thuộc loài: ${speciesName}.`
    : "Không rõ loài cây.";

  const prompt = `${speciesHint}
Hãy phân tích ảnh cây và trả về JSON THUẦN TÚY theo đúng cấu trúc sau:
{
  "health_status": "healthy" | "diseased" | "needs_attention",
  "findings": [
    {
      "reported_name": "tên bệnh/vấn đề",
      "confidence": 0.95,
      "symptoms": "mô tả triệu chứng",
      "possible_cause": "nguyên nhân có thể",
      "treatment_steps": ["bước 1", "bước 2"]
    }
  ]
}
Nếu cây khỏe mạnh, trả về findings là mảng rỗng []. Phản hồi hoàn toàn bằng tiếng Việt.`;

  const body = {
    contents: [
      {
        parts: [
          { text: prompt },
          {
            inline_data: {
              mime_type: mimeType,
              data: base64,
            },
          },
        ],
      },
    ],
    generationConfig: {
      response_mime_type: "application/json",
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    signal: AbortSignal.timeout(30_000),
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new HttpError(
      502,
      "GEMINI_ERROR",
      `Gemini API lỗi (${res.status}): ${text.slice(0, 200)}`,
    );
  }

  const json = (await res.json()) as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
    }>;
  };

  const rawText = json.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  let parsed: GeminiDiagnoseResult;
  try {
    parsed = JSON.parse(rawText) as GeminiDiagnoseResult;
  } catch {
    throw new HttpError(
      502,
      "GEMINI_PARSE_ERROR",
      "Gemini trả về dữ liệu không hợp lệ.",
    );
  }

  // Chuẩn hóa health_status sang DB enum
  const rawStatus = String(parsed.health_status ?? "unknown");
  const statusMap: Record<string, HealthStatus> = {
    healthy: "healthy",
    diseased: "suspected",
    needs_attention: "suspected",
    unknown: "unknown",
  };
  const health_status: HealthStatus = statusMap[rawStatus] ?? "unknown";

  return { health_status, findings: parsed.findings ?? [] };
}

// ─── Helper: Dữ liệu mẫu (mock) ──────────────────────────────────────────────

function mockIdentifyResult(): PlantNetResult {
  return {
    scientific_name: "Epipremnum aureum",
    common_name: "Trầu bà",
    confidence: 0.95,
  };
}

function mockDiagnoseResult(): GeminiDiagnoseResult {
  return {
    health_status: "healthy",
    findings: [
      {
        reported_name: "Dữ liệu mẫu - Cây khỏe mạnh",
        confidence: 0.9,
        symptoms: "Lá xanh tươi, không có dấu hiệu bệnh.",
        possible_cause: null,
        treatment_steps: [
          "Tiếp tục tưới nước đều đặn.",
          "Đảm bảo ánh sáng phù hợp.",
        ],
      },
    ],
  };
}

// ─── Helper: Tìm hoặc tạo plant_species ──────────────────────────────────────

interface SpeciesQueryResult {
  id: string;
  scientific_name: string;
  common_name: string | null;
  displayName: string;
}

async function findOrCreateSpecies(
  db: Database,
  config: Config,
  scientificName: string,
  useMock = false,
): Promise<SpeciesQueryResult> {
  const trimmedSci = scientificName.trim();

  // Tìm theo tên khoa học (không phân biệt hoa thường)
  const existing = await db.$queryRaw<
    { id: string; scientific_name: string; common_name: string | null; common_name_locale: string | null }[]
  >`
    SELECT id, scientific_name, common_name, common_name_locale FROM plantcare.plant_species
    WHERE lower(btrim(scientific_name)) = lower(btrim(${trimmedSci}))
    LIMIT 1
  `;

  if (existing.length > 0) {
    const item = existing[0];
    // Nếu đã tồn tại và common_name_locale === "vi" kèm common_name có giá trị: dùng lại
    if (item.common_name_locale === "vi" && item.common_name?.trim()) {
      return {
        id: item.id,
        scientific_name: item.scientific_name,
        common_name: item.common_name,
        displayName: formatSpeciesDisplayName(item.scientific_name, item.common_name),
      };
    }

    // Nếu đã tồn tại nhưng common_name_locale !== "vi": dịch sang tiếng Việt
    const vietnameseName = useMock
      ? "Trầu bà"
      : await translateSpeciesToVietnamese(item.scientific_name, config);

    if (vietnameseName) {
      await db.plant_species.update({
        where: { id: item.id },
        data: {
          common_name: vietnameseName,
          common_name_locale: "vi",
        },
      });
      return {
        id: item.id,
        scientific_name: item.scientific_name,
        common_name: vietnameseName,
        displayName: formatSpeciesDisplayName(item.scientific_name, vietnameseName),
      };
    }

    return {
      id: item.id,
      scientific_name: item.scientific_name,
      common_name: item.common_name,
      displayName: formatSpeciesDisplayName(item.scientific_name, item.common_name),
    };
  }

  // Chưa tồn tại: dịch tên tiếng Việt
  const vietnameseName = useMock
    ? "Trầu bà"
    : await translateSpeciesToVietnamese(trimmedSci, config);

  const created = await db.plant_species.create({
    data: {
      scientific_name: trimmedSci,
      common_name: vietnameseName,
      common_name_locale: vietnameseName ? "vi" : null,
      care_status: "missing",
    },
    select: { id: true, scientific_name: true, common_name: true },
  });

  return {
    id: created.id,
    scientific_name: created.scientific_name,
    common_name: created.common_name,
    displayName: formatSpeciesDisplayName(created.scientific_name, created.common_name),
  };
}

// ─── Service Factory ──────────────────────────────────────────────────────────

export function scanService(db: Database, config: Config) {
  const storage: PlantImageStorage = plantImageStorage(config);

  /**
   * Kiểm tra cây thuộc về ownerId.
   * Trả về species_id (nếu có) để dùng cho chẩn đoán.
   */
  async function verifyPlantOwnership(
    plantId: string,
    ownerId: string,
  ): Promise<string | null> {
    const plant = await db.plants.findFirst({
      where: { id: plantId, owner_id: ownerId },
      select: { species_id: true },
    });
    if (!plant) {
      throw new HttpError(
        404,
        "PLANT_NOT_FOUND",
        "Không tìm thấy cây hoặc bạn không có quyền truy cập.",
      );
    }
    return plant.species_id ?? null;
  }

  return {
    /**
     * Tạo một bản quét mới (identify hoặc diagnose).
     */
    async create(
      ownerId: string,
      data: CreateScanInput,
    ): Promise<ScanResult> {
      // 1. Validate mode
      if (!SCAN_MODES.includes(data.mode as ScanMode)) {
        throw new HttpError(
          400,
          "INVALID_MODE",
          `Chế độ quét không hợp lệ. Phải là một trong: ${SCAN_MODES.join(", ")}.`,
        );
      }
      const mode = data.mode as ScanMode;

      // 2. Idempotency check TRƯỚC khi upload ảnh để tránh upload trùng
      if (data.request_id) {
        const existing = await db.scans.findUnique({
          where: { owner_id_request_id: { owner_id: ownerId, request_id: data.request_id } },
          include: { scan_findings: { orderBy: { position: "asc" } } },
        });
        if (existing) {
          const image_url = await storage.createSignedUrl(existing.image_key);
          return { ...existing, image_url, isExisting: true };
        }
      }

      // 3. Kiểm tra quyền sở hữu cây (nếu có plant_id)
      let speciesIdFromPlant: string | null = null;
      if (data.plant_id) {
        speciesIdFromPlant = await verifyPlantOwnership(data.plant_id, ownerId);
      }

      // 4. Upload ảnh lên Supabase Storage (dọn dẹp nếu DB gặp sự cố)
      let image_key: string | null = null;
      try {
        image_key = await storage.upload(
          data.imageBuffer,
          data.mimeType,
          ownerId,
        );

        // 5. Sinh request_id nếu không có
        const request_id = data.request_id ?? randomUUID();
        const organ = data.organ ?? "auto";

        // 6. Xử lý theo mode
        const useMock =
          config.CARE_AI_MODE === "demo" ||
          (config.CARE_AI_MODE === "auto" &&
            !config.PLANTNET_API_KEY &&
            !config.GEMINI_API_KEY);

        let scan: Scan & { scan_findings: ScanFinding[] };

        if (mode === "identify") {
          scan = await handleIdentify({
            ownerId,
            request_id,
            plant_id: data.plant_id ?? null,
            image_key,
            organ,
            imageBuffer: data.imageBuffer,
            mimeType: data.mimeType,
            useMock,
          });
        } else if (mode === "diagnose") {
          scan = await handleDiagnose({
            ownerId,
            request_id,
            plant_id: data.plant_id ?? null,
            image_key,
            imageBuffer: data.imageBuffer,
            mimeType: data.mimeType,
            useMock,
            speciesIdFromPlant,
          });
        } else {
          // mode === "both"
          scan = await handleBoth({
            ownerId,
            request_id,
            plant_id: data.plant_id ?? null,
            image_key,
            organ,
            imageBuffer: data.imageBuffer,
            mimeType: data.mimeType,
            useMock,
          });
        }

        const image_url = await storage.createSignedUrl(scan.image_key);
        return { ...scan, image_url, isExisting: false };
      } catch (error) {
        // Dọn rác storage nếu ghi DB thất bại
        if (image_key) {
          try {
            await storage.remove(image_key);
          } catch {
            // Không để lỗi dọn dẹp che mất lỗi gốc
          }
        }
        throw error;
      }
    },

    /**
     * Lấy danh sách scans của ownerId, kèm signed URLs.
     */
    async listByOwner(
      ownerId: string,
      query?: ListScansQuery,
    ): Promise<ScanListItem[]> {
      const limit = query?.limit && query.limit > 0 ? query.limit : 50;
      const scans = await db.scans.findMany({
        where: {
          owner_id: ownerId,
          ...(query?.mode ? { mode: query.mode } : {}),
          ...(query?.plant_id ? { plant_id: query.plant_id } : {}),
        },
        orderBy: { scanned_at: "desc" },
        take: limit,
      });

      const urlMap = await storage.createSignedUrls(scans.map((s) => s.image_key));
      return scans.map((s) => ({
        ...s,
        image_url: urlMap.get(s.image_key) ?? null,
      }));
    },

    /**
     * Lấy chi tiết một scan (kèm findings và signed image_url).
     */
    async getById(
      ownerId: string,
      scanId: string,
    ): Promise<ScanResult> {
      const scan = await db.scans.findFirst({
        where: { id: scanId, owner_id: ownerId },
        include: { scan_findings: { orderBy: { position: "asc" } } },
      });
      if (!scan) {
        throw new HttpError(
          404,
          "SCAN_NOT_FOUND",
          "Không tìm thấy kết quả quét.",
        );
      }
      const image_url = await storage.createSignedUrl(scan.image_key);
      return { ...scan, image_url };
    },

    /**
     * Xóa một scan:
     * Chỉ xóa file trên storage nếu không còn cây nào trong vườn dùng ảnh này làm cover_image_key.
     */
    async remove(ownerId: string, scanId: string): Promise<void> {
      const scan = await db.scans.findFirst({
        where: { id: scanId, owner_id: ownerId },
        select: { id: true, image_key: true },
      });
      if (!scan) {
        throw new HttpError(
          404,
          "SCAN_NOT_FOUND",
          "Không tìm thấy kết quả quét để xóa.",
        );
      }

      await db.scans.delete({ where: { id: scanId } });

      // Kiểm tra bảng plants xem còn cây nào dùng image_key này làm cover_image_key không
      const plantUsingImage = await db.plants.findFirst({
        where: { cover_image_key: scan.image_key },
        select: { id: true },
      });
      if (!plantUsingImage) {
        try {
          await storage.remove(scan.image_key);
        } catch {
          // Bỏ qua lỗi xóa file
        }
      }
    },
  };

  // ─── Luồng Identify ─────────────────────────────────────────────────────────

  async function handleIdentify(params: {
    ownerId: string;
    request_id: string;
    plant_id: string | null;
    image_key: string;
    organ: string;
    imageBuffer: Buffer;
    mimeType: string;
    useMock: boolean;
  }): Promise<Scan & { scan_findings: ScanFinding[] }> {
    const usePlantNet =
      !params.useMock &&
      config.CARE_AI_MODE !== "demo" &&
      !!config.PLANTNET_API_KEY;

    let result: PlantNetResult;
    let isMock = false;

    if (usePlantNet) {
      result = await callPlantNet(
        params.imageBuffer,
        params.mimeType,
        config.PLANTNET_PROJECT,
        config.PLANTNET_API_KEY,
        params.organ,
      );
    } else {
      result = mockIdentifyResult();
      isMock = true;
    }

    const species = await findOrCreateSpecies(
      db,
      config,
      result.scientific_name,
      isMock,
    );

    const scan = await db.scans.create({
      data: {
        owner_id: params.ownerId,
        request_id: params.request_id,
        plant_id: params.plant_id,
        image_key: params.image_key,
        mode: "identify",
        source: isMock ? "mock" : "plantnet",
        is_mock: isMock,
        species_id: species.id,
        reported_species_name: species.displayName,
        species_confidence: result.confidence,
        health_status: "unknown",
      },
      include: { scan_findings: true },
    });

    return scan;
  }

  // ─── Luồng Diagnose ──────────────────────────────────────────────────────────

  async function handleDiagnose(params: {
    ownerId: string;
    request_id: string;
    plant_id: string | null;
    image_key: string;
    imageBuffer: Buffer;
    mimeType: string;
    useMock: boolean;
    speciesIdFromPlant: string | null;
  }): Promise<Scan & { scan_findings: ScanFinding[] }> {
    let speciesName: string | null = null;
    let reportedSpeciesName: string | null = null;

    if (params.speciesIdFromPlant) {
      const species = await db.plant_species.findUnique({
        where: { id: params.speciesIdFromPlant },
        select: { id: true, scientific_name: true, common_name: true, common_name_locale: true },
      });
      if (species) {
        speciesName = species.scientific_name;
        let vietnameseName = species.common_name;
        if (species.common_name_locale !== "vi") {
          const translated = await translateSpeciesToVietnamese(species.scientific_name, config);
          if (translated) {
            vietnameseName = translated;
            await db.plant_species.update({
              where: { id: species.id },
              data: { common_name: translated, common_name_locale: "vi" },
            }).catch(() => {});
          }
        }
        reportedSpeciesName = formatSpeciesDisplayName(species.scientific_name, vietnameseName);
      }
    }

    const useGemini =
      !params.useMock &&
      config.CARE_AI_MODE !== "demo" &&
      !!config.GEMINI_API_KEY;

    let diagnoseResult: GeminiDiagnoseResult;
    let isMock = false;

    if (useGemini) {
      diagnoseResult = await callGeminiVision(
        params.imageBuffer,
        params.mimeType,
        config.GEMINI_API_KEY,
        config.GEMINI_MODEL,
        speciesName,
      );
    } else {
      diagnoseResult = mockDiagnoseResult();
      isMock = true;
    }

    // Tạo scan + findings trong transaction
    const scan = await db.$transaction(async (tx) => {
      const created = await tx.scans.create({
        data: {
          owner_id: params.ownerId,
          request_id: params.request_id,
          plant_id: params.plant_id,
          image_key: params.image_key,
          mode: "diagnose",
          source: isMock ? "mock" : "gemini",
          is_mock: isMock,
          species_id: params.speciesIdFromPlant,
          reported_species_name: reportedSpeciesName,
          health_status: diagnoseResult.health_status,
        },
      });

      if (diagnoseResult.findings.length > 0) {
        await tx.scan_findings.createMany({
          data: diagnoseResult.findings.map((f, i) => ({
            scan_id: created.id,
            position: i,
            reported_name: f.reported_name,
            confidence: f.confidence ?? null,
            symptoms: f.symptoms ?? null,
            possible_cause: f.possible_cause ?? null,
            treatment_steps: f.treatment_steps ?? [],
            guidance_source: isMock ? "mock" : "gemini",
          })),
        });
      }

      return tx.scans.findFirst({
        where: { id: created.id },
        include: { scan_findings: { orderBy: { position: "asc" } } },
      });
    });

    if (!scan) {
      throw new HttpError(500, "INTERNAL_ERROR", "Không thể tạo bản quét.");
    }
    return scan;
  }

  // ─── Luồng Both ──────────────────────────────────────────────────────────────

  async function handleBoth(params: {
    ownerId: string;
    request_id: string;
    plant_id: string | null;
    image_key: string;
    organ: string;
    imageBuffer: Buffer;
    mimeType: string;
    useMock: boolean;
  }): Promise<Scan & { scan_findings: ScanFinding[] }> {
    // Bước 1: Identify để lấy species
    const usePlantNet =
      !params.useMock &&
      config.CARE_AI_MODE !== "demo" &&
      !!config.PLANTNET_API_KEY;

    let identifyResult: PlantNetResult;
    let isMock = false;

    if (usePlantNet) {
      identifyResult = await callPlantNet(
        params.imageBuffer,
        params.mimeType,
        config.PLANTNET_PROJECT,
        config.PLANTNET_API_KEY,
        params.organ,
      );
    } else {
      identifyResult = mockIdentifyResult();
      isMock = true;
    }

    const species = await findOrCreateSpecies(
      db,
      config,
      identifyResult.scientific_name,
      isMock,
    );

    // Bước 2: Diagnose với tên loài vừa xác định
    const useGemini =
      !params.useMock &&
      config.CARE_AI_MODE !== "demo" &&
      !!config.GEMINI_API_KEY;

    let diagnoseResult: GeminiDiagnoseResult;
    if (useGemini) {
      diagnoseResult = await callGeminiVision(
        params.imageBuffer,
        params.mimeType,
        config.GEMINI_API_KEY,
        config.GEMINI_MODEL,
        species.displayName,
      );
    } else {
      diagnoseResult = mockDiagnoseResult();
      isMock = true;
    }

    // Lưu scan "both" + findings trong transaction
    const scan = await db.$transaction(async (tx) => {
      const created = await tx.scans.create({
        data: {
          owner_id: params.ownerId,
          request_id: params.request_id,
          plant_id: params.plant_id,
          image_key: params.image_key,
          mode: "both",
          source: isMock ? "mock" : "plantnet+gemini",
          is_mock: isMock,
          species_id: species.id,
          reported_species_name: species.displayName,
          species_confidence: identifyResult.confidence,
          health_status: diagnoseResult.health_status,
        },
      });

      if (diagnoseResult.findings.length > 0) {
        await tx.scan_findings.createMany({
          data: diagnoseResult.findings.map((f, i) => ({
            scan_id: created.id,
            position: i,
            reported_name: f.reported_name,
            confidence: f.confidence ?? null,
            symptoms: f.symptoms ?? null,
            possible_cause: f.possible_cause ?? null,
            treatment_steps: f.treatment_steps ?? [],
            guidance_source: isMock ? "mock" : "gemini",
          })),
        });
      }

      return tx.scans.findFirst({
        where: { id: created.id },
        include: { scan_findings: { orderBy: { position: "asc" } } },
      });
    });

    if (!scan) {
      throw new HttpError(500, "INTERNAL_ERROR", "Không thể tạo bản quét.");
    }
    return scan;
  }
}
