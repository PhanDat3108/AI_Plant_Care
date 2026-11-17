import { Router } from "express";
import type { Database } from "../config/database.js";
import { notificationController } from "../controllers/notifications.js";

export function notificationsRoutes(db: Database) {
  const router = Router();
  const controller = notificationController(db);
  router.get("/notifications", controller.list);
  router.get("/notifications/unread-count", controller.unreadCount);
  router.patch("/notifications/:id/read", controller.markRead);
  return router;
}
