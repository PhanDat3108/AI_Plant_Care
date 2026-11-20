import type { Request, Response, NextFunction, RequestHandler } from "express";
import { z } from "zod";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { success, HttpError } from "../middlewares/errors.js";
import {
  scanService,
  SCAN_MODES,
  ALLOWED_MIME_TYPES,
  type AllowedMimeType,
} from "../services/scans.js";

/**
 * Trích xuất ownerId từ req.user.id hoặc res.locals.user.id
 */
function getOwnerId(req: Request, res: Response): string {
  const user = (req as Request & { user?: { id: string } }).user || res.locals?.user;
  if (!user?.id) {
    throw new HttpError(401, "UNAUTHORIZED", "Yêu cầu đăng nhập.");
  }
  return user.id;
}

const createScanSchema = z.object({
  mode: z.enum(SCAN_MODES).default("identify"),
  organ: z.string().trim().optional().nullable(),
  plant_id: z.string().uuid("plant_id phải là định dạng UUID hợp lệ.").optional().nullable(),
  request_id: z.string().uuid("request_id phải là định dạng UUID hợp lệ.").optional().nullable(),
  image_base64: z.string().optional(),
});

const listScansQuerySchema = z.object({
  mode: z.string().trim().optional(),
  plant_id: z.string().uuid().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

/**
 * Phân tích dữ liệu base64 (hỗ trợ Data URL prefix hoặc base64 thuần)
 */
function parseBase64Image(raw: string): { buffer: Buffer; mimeType: string } {
  const match = raw.match(/^data:([^;]+);base64,(.*)$/);
  if (match) {
    const mimeType = match[1];
    const buffer = Buffer.from(match[2], "base64");
    return { buffer, mimeType };
  }
  return {
    buffer: Buffer.from(raw, "base64"),
    mimeType: "image/jpeg",
  };
}

export function scansController(db: Database, config: Config): {
  create: RequestHandler;
  list: RequestHandler;
  getById: RequestHandler;
  remove: RequestHandler;
} {
  const service = scanService(db, config);

  return {
    /**
     * POST /scans
     * Nhận file qua req.file (field "image") hoặc base64 từ req.body.image_base64
     */
    async create(req: Request, res: Response, next: NextFunction) {
      try {
        const ownerId = getOwnerId(req, res);
        const validated = createScanSchema.parse(req.body);

        let imageBuffer: Buffer | null = null;
        let mimeType: string | null = null;

        if (req.file) {
          imageBuffer = req.file.buffer;
          mimeType = req.file.mimetype;
        } else if (validated.image_base64 && validated.image_base64.trim()) {
          const parsed = parseBase64Image(validated.image_base64.trim());
          imageBuffer = parsed.buffer;
          mimeType = parsed.mimeType;
        }

        if (!imageBuffer || !mimeType) {
          throw new HttpError(
            400,
            "MISSING_IMAGE",
            "Vui lòng tải lên file ảnh (multipart field 'image') hoặc gửi chuỗi image_base64.",
          );
        }

        if (!ALLOWED_MIME_TYPES.includes(mimeType as AllowedMimeType)) {
          throw new HttpError(
            400,
            "INVALID_IMAGE_TYPE",
            `Định dạng ảnh '${mimeType}' không được hỗ trợ. Chỉ chấp nhận: ${ALLOWED_MIME_TYPES.join(", ")}.`,
          );
        }

        const scanResult = await service.create(ownerId, {
          mode: validated.mode,
          imageBuffer,
          mimeType,
          request_id: validated.request_id ?? null,
          plant_id: validated.plant_id ?? null,
          organ: validated.organ ?? null,
        });

        // 200 nếu bản ghi đã tồn tại do idempotent request_id, 201 nếu tạo mới
        const statusCode = scanResult.isExisting ? 200 : 201;
        res.status(statusCode);
        success(res, scanResult);
      } catch (error) {
        next(error);
      }
    },

    /**
     * GET /scans
     * Lấy danh sách lịch sử quét của người dùng
     */
    async list(req: Request, res: Response, next: NextFunction) {
      try {
        const ownerId = getOwnerId(req, res);
        const query = listScansQuerySchema.parse(req.query);
        const scans = await service.listByOwner(ownerId, query);
        success(res, scans);
      } catch (error) {
        next(error);
      }
    },

    /**
     * GET /scans/:id
     * Lấy chi tiết một lần quét kèm kết quả phân tích / chẩn đoán
     */
    async getById(req: Request, res: Response, next: NextFunction) {
      try {
        const ownerId = getOwnerId(req, res);
        const scanId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
        if (!scanId) {
          throw new HttpError(400, "INVALID_INPUT", "Thiếu scan id.");
        }
        const scan = await service.getById(ownerId, scanId);
        success(res, scan);
      } catch (error) {
        next(error);
      }
    },

    /**
     * DELETE /scans/:id
     * Xóa kết quả quét
     */
    async remove(req: Request, res: Response, next: NextFunction) {
      try {
        const ownerId = getOwnerId(req, res);
        const scanId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
        if (!scanId) {
          throw new HttpError(400, "INVALID_INPUT", "Thiếu scan id.");
        }
        await service.remove(ownerId, scanId);
        success(res, { id: scanId, deleted: true });
      } catch (error) {
        next(error);
      }
    },
  };
}
