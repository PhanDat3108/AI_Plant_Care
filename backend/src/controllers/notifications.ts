import type { RequestHandler } from "express";
import { z } from "zod";
import type { Database } from "../config/database.js";
import { HttpError, success } from "../middlewares/errors.js";
import {
  notificationService,
  type NotificationCursor,
} from "../services/notifications.js";
const query = z.strictObject({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  unread: z.enum(["true", "false"]).default("false"),
  cursor: z
    .string()
    .min(1)
    .max(256)
    .regex(/^[A-Za-z0-9_-]+$/)
    .optional(),
});
function decodeCursor(value?: string): NotificationCursor | undefined {
  if (!value) return undefined;
  try {
    return z
      .strictObject({ id: z.uuid(), created_at: z.iso.datetime() })
      .parse(JSON.parse(Buffer.from(value, "base64url").toString("utf8")));
  } catch {
    throw new HttpError(
      400,
      "INVALID_INPUT",
      "Cursor phân trang không hợp lệ.",
    );
  }
}
export function notificationController(db: Database): {
  list: RequestHandler;
  unreadCount: RequestHandler;
  markRead: RequestHandler;
} {
  const service = notificationService(db);
  return {
    async list(req, res) {
      const input = query.parse(req.query);
      success(
        res,
        await service.list(
          res.locals.user.id,
          input.limit,
          input.unread === "true",
          decodeCursor(input.cursor),
        ),
      );
    },
    async unreadCount(_req, res) {
      success(res, await service.unreadCount(res.locals.user.id));
    },
    async markRead(req, res) {
      success(
        res,
        await service.markRead(
          res.locals.user.id,
          z.uuid().parse(req.params.id),
        ),
      );
    },
  };
}
