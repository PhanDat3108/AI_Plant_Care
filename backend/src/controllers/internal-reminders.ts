import type { RequestHandler } from "express";
import type { Database } from "../config/database.js";
import { success } from "../middlewares/errors.js";
import { scheduledReminderService } from "../services/scheduled-reminders.js";

export function internalReminderController(db: Database): RequestHandler {
  const service = scheduledReminderService(db);
  return async (_req, res) => {
    res.setHeader("Cache-Control", "no-store");
    success(res, await service.run());
  };
}
