import { Router } from "express";
import type { Database } from "../config/database.js";
import { carePlanController } from "../controllers/care-plan.js";

export function carePlanRoutes(db: Database) {
  const router = Router();
  const controller = carePlanController(db);
  router.post("/plants/:id/care-plan/sync", controller.sync);
  router.get("/care-tasks", controller.tasks);
  return router;
}
