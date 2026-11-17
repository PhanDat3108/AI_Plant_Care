import { Router } from "express";
import type { Database } from "../config/database.js";
import { scheduleController } from "../controllers/schedules.js";

export function schedulesRoutes(db: Database) {
  const router = Router();
  const controller = scheduleController(db);
  router.get("/plants/:id/schedules", controller.list);
  router.put("/plants/:id/schedules/:kind", controller.save);
  return router;
}
