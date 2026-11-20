import { randomUUID } from "node:crypto";
import { promises as fs } from "node:fs";
import path from "node:path";
import type { scansModel } from "../generated/prisma/models/scans.js";
import type { scan_findingsModel } from "../generated/prisma/models/scan_findings.js";
import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";
import type { Config } from "../config/env.js";

// ─── Types & Constants ────────────────────────────────────────────────────────

export type Scan = scansModel;
export type ScanFinding = scan_findingsModel;
export type ScanResult = Scan & {
  scan_findings: ScanFinding[];
  isExisting?: boolean;
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

// ─── Helper: Lưu ảnh ─────────────────────────────────────────────────────────

/**
 * Kiểm tra MIME type và lưu buffer ảnh vào thư mục upload.
 * Trả về image_key (đường dẫn tương đối) để lưu vào database.
 */
export async function saveImage(
  buffer: Buffer,
  mimeType: string,
  ownerId: string,
  uploadDir: string,
): Promise<string> {
  if (!ALLOWED_MIME_TYPES.includes(mimeType as AllowedMimeType)) {
    throw new HttpError(
      400,
      "INVALID_IMAGE_TYPE",
      `Định dạng ảnh không được hỗ trợ. Chỉ chấp nhận: ${ALLOWED_MIME_TYPES.join(", ")}.`,
    );
  }
  const ext = MIME_TO_EXT[mimeType as AllowedMimeType];
  const fileName = `${randomUUID()}.${ext}`;
  const dirPath = path.join(uploadDir, "scans", ownerId);
  await fs.mkdir(dirPath, { recursive: true });
  await fs.writeFile(path.join(dirPath, fileName), buffer);
  return `scans/${ownerId}/${fileName}`;
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
  const url = `https://my-api.plantnet.org/v2/identify/${project}?api-key=${apiKey}&lang=vi`;
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
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  const base64 = imageBuffer.toString("base64");

  const speciesHint = speciesName
    ? `Cây này thuộc loài: ${speciesName}.`
    : "Không rõ loài cây.";

  const prompt = `${speciesHint}
Hãy phân tích ảnh cây và trả về JSON THUẦN TÚY (không có markdown, không có \`\`\`json) theo đúng cấu trúc sau:
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
    headers: { "Content-Type": "application/json" },
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

async function findOrCreateSpecies(
  db: Database,
  scientificName: string,
  commonName: string | null,
): Promise<string> {
  // Tìm theo tên khoa học (không phân biệt hoa thường)
  const existing = await db.$queryRaw<{ id: string }[]>`
    SELECT id FROM plantcare.plant_species
    WHERE lower(btrim(scientific_name)) = lower(btrim(${scientificName}))
    LIMIT 1
  `;

  if (existing.length > 0) return existing[0].id;

  // Tạo mới với care_status = 'missing' để trigger luồng sinh dữ liệu chăm sóc
  const created = await db.plant_species.create({
    data: {
      scientific_name: scientificName,
      common_name: commonName,
      care_status: "missing",
    },
    select: { id: true },
  });
  return created.id;
}

// ─── Service Factory ──────────────────────────────────────────────────────────

export function scanService(db: Database, config: Config) {
  const uploadDir = config.UPLOAD_DIR;

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

      // 2. Idempotency: nếu request_id đã tồn tại thì trả về bản ghi cũ
      if (data.request_id) {
        const existing = await db.scans.findUnique({
          where: { owner_id_request_id: { owner_id: ownerId, request_id: data.request_id } },
          include: { scan_findings: true },
        });
        if (existing) return { ...existing, isExisting: true };
      }

      // 3. Kiểm tra quyền sở hữu cây (nếu có plant_id)
      let speciesIdFromPlant: string | null = null;
      if (data.plant_id) {
        speciesIdFromPlant = await verifyPlantOwnership(data.plant_id, ownerId);
      }

      // 4. Lưu ảnh
      const image_key = await saveImage(
        data.imageBuffer,
        data.mimeType,
        ownerId,
        uploadDir,
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

      if (mode === "identify") {
        return handleIdentify({
          ownerId, request_id, plant_id: data.plant_id ?? null,
          image_key, organ, imageBuffer: data.imageBuffer,
          mimeType: data.mimeType, useMock,
        });
      }

      if (mode === "diagnose") {
        return handleDiagnose({
          ownerId, request_id, plant_id: data.plant_id ?? null,
          image_key, imageBuffer: data.imageBuffer, mimeType: data.mimeType,
          useMock, speciesIdFromPlant,
        });
      }

      // mode === "both": chạy identify trước, lấy species rồi diagnose
      return handleBoth({
        ownerId, request_id, plant_id: data.plant_id ?? null,
        image_key, organ, imageBuffer: data.imageBuffer,
        mimeType: data.mimeType, useMock,
      });
    },

    /**
     * Lấy danh sách scans của ownerId, hỗ trợ lọc tùy chọn.
     */
    async listByOwner(
      ownerId: string,
      query?: ListScansQuery,
    ): Promise<Scan[]> {
      const limit = query?.limit && query.limit > 0 ? query.limit : 50;
      return db.scans.findMany({
        where: {
          owner_id: ownerId,
          ...(query?.mode ? { mode: query.mode } : {}),
          ...(query?.plant_id ? { plant_id: query.plant_id } : {}),
        },
        orderBy: { scanned_at: "desc" },
        take: limit,
      });
    },

    /**
     * Lấy chi tiết một scan (kèm findings).
     */
    async getById(
      ownerId: string,
      scanId: string,
    ): Promise<Scan & { scan_findings: ScanFinding[] }> {
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
      return scan;
    },

    /**
     * Xóa một scan (kèm findings do Cascade).
     */
    async remove(ownerId: string, scanId: string): Promise<void> {
      const scan = await db.scans.findFirst({
        where: { id: scanId, owner_id: ownerId },
        select: { id: true },
      });
      if (!scan) {
        throw new HttpError(
          404,
          "SCAN_NOT_FOUND",
          "Không tìm thấy kết quả quét để xóa.",
        );
      }
      await db.scans.delete({ where: { id: scanId } });
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

    const species_id = await findOrCreateSpecies(
      db,
      result.scientific_name,
      result.common_name,
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
        species_id,
        reported_species_name: result.scientific_name,
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
    // Lấy tên loài từ species_id nếu có
    let speciesName: string | null = null;
    if (params.speciesIdFromPlant) {
      const species = await db.plant_species.findUnique({
        where: { id: params.speciesIdFromPlant },
        select: { scientific_name: true },
      });
      speciesName = species?.scientific_name ?? null;
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

    const species_id = await findOrCreateSpecies(
      db,
      identifyResult.scientific_name,
      identifyResult.common_name,
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
        identifyResult.scientific_name,
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
          species_id,
          reported_species_name: identifyResult.scientific_name,
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
