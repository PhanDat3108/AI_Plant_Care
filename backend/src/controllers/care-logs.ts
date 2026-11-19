import type { Request, Response, NextFunction, RequestHandler } from "express";
import { z } from "zod";
import type { Database } from "../config/database.js";
import { success, HttpError } from "../middlewares/errors.js";
import {
  careLogService,
  createCareLog,
  listCareLogsByPlant,
  updateCareLog,
  deleteCareLog,
  CARE_LOG_KINDS,
} from "../services/care-logs.js";

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

const createBodySchema = z.object({
  kind: z.enum(CARE_LOG_KINDS, {
    message: `Loại chăm sóc (kind) là bắt buộc và phải là một trong: ${CARE_LOG_KINDS.join(", ")}.`,
  }),
  note: z.string().trim().optional().nullable(),
  performed_at: z.union([z.string(), z.date()]).optional().nullable(),
  request_id: z.string().trim().optional().nullable(),
  task_id: z.string().trim().optional().nullable(),
});

const listQuerySchema = z.object({
  kind: z.string().trim().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

const updateBodySchema = z.object({
  kind: z.enum(CARE_LOG_KINDS).optional(),
  note: z.string().trim().optional().nullable(),
  performed_at: z.union([z.string(), z.date()]).optional().nullable(),
});

export function careLogsController(db: Database): {
  create: RequestHandler;
  list: RequestHandler;
  update: RequestHandler;
  remove: RequestHandler;
} {
  const service = careLogService(db);

  return {
    async create(req: Request, res: Response, next: NextFunction) {
      try {
        const ownerId = getOwnerId(req, res);
        const plantId = z.string().trim().min(1, "plantId không hợp lệ.").parse(req.params.id);
        const body = createBodySchema.parse(req.body);

        const log = await service.create(ownerId, plantId, body);
        res.status(201).json({
          success: true,
          data: log,
          error: null,
          message: "Tạo nhật ký chăm sóc thành công.",
        });
      } catch (error) {
        next(error);
      }
    },

    async list(req: Request, res: Response, next: NextFunction) {
      try {
        const ownerId = getOwnerId(req, res);
        const plantId = z.string().trim().min(1, "plantId không hợp lệ.").parse(req.params.id);
        const query = listQuerySchema.parse(req.query);

        const logs = await service.listByPlant(ownerId, plantId, query);
        success(res, logs);
      } catch (error) {
        next(error);
      }
    },

    async update(req: Request, res: Response, next: NextFunction) {
      try {
        const ownerId = getOwnerId(req, res);
        const logId = z
          .string()
          .trim()
          .min(1, "logId không hợp lệ.")
          .parse(req.params.logId || req.params.id);
        const body = updateBodySchema.parse(req.body);

        const updated = await service.update(ownerId, logId, body);
        success(res, updated);
      } catch (error) {
        next(error);
      }
    },

    async remove(req: Request, res: Response, next: NextFunction) {
      try {
        const ownerId = getOwnerId(req, res);
        const logId = z
          .string()
          .trim()
          .min(1, "logId không hợp lệ.")
          .parse(req.params.logId || req.params.id);

        const removed = await service.delete(ownerId, logId);
        success(res, removed);
      } catch (error) {
        next(error);
      }
    },
  };
}

export const careLogController = careLogsController;

export {
  createCareLog,
  listCareLogsByPlant,
  updateCareLog,
  deleteCareLog,
};
