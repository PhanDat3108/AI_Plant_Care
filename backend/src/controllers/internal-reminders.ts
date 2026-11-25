import type { Config } from "../config/env.js";
import { firebasePushSender } from "../config/firebase.js";
import { pushNotificationService } from "../services/push-notifications.js";
import type { RequestHandler } from "express";
import type { Database } from "../config/database.js";
import { success } from "../middlewares/errors.js";
import { scheduledReminderService } from "../services/scheduled-reminders.js";

export function internalReminderController(
  db: Database,
  config: Config,
): RequestHandler {
  const service = scheduledReminderService(
    db,
    pushNotificationService(db, firebasePushSender(config)),
  );
  return async (_req, res) => {
    res.setHeader("Cache-Control", "no-store");
    success(res, await service.run());
  };
}
