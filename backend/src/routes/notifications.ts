import { Router } from "express";
import type { Database } from "../config/database.js";
import { pushDeviceController } from "../controllers/push-devices.js";
import { notificationController } from "../controllers/notifications.js";

export function notificationsRoutes(db: Database) {
  const router = Router();
  const controller = notificationController(db);
  const devices = pushDeviceController(db);
  router.post("/notifications/devices", devices.register);
  router.delete("/notifications/devices/:id", devices.remove);
  router.get("/notifications", controller.list);
  router.get("/notifications/unread-count", controller.unreadCount);
  router.patch("/notifications/:id/read", controller.markRead);
  return router;
}
