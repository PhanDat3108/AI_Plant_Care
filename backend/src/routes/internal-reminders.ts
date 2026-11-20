import { Router } from "express";
import { createHash, timingSafeEqual } from "node:crypto";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { HttpError } from "../middlewares/errors.js";
import { internalReminderController } from "../controllers/internal-reminders.js";

export function internalReminderRoutes(db: Database, config: Config) {
  const router = Router();
  router.post(
    "/run",
    (req, _res, next) => {
      if (!config.CRON_SECRET)
        throw new HttpError(
          503,
          "CRON_NOT_CONFIGURED",
          "Chưa cấu hình tác vụ định kỳ.",
        );
      const supplied = req.get("X-Cron-Secret");
      const digest = (value: string) =>
        createHash("sha256").update(value).digest();
      if (
        !supplied ||
        !timingSafeEqual(digest(supplied), digest(config.CRON_SECRET))
      ) {
        throw new HttpError(
          401,
          "UNAUTHORIZED",
          "Thông tin xác thực tác vụ không hợp lệ.",
        );
      }
      next();
    },
    internalReminderController(db),
  );
  return router;
}
