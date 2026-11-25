import { Router } from "express";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { carePlanController } from "../controllers/care-plan.js";

export function carePlanRoutes(db: Database, config?: Config) {
  const router = Router();
  const controller = carePlanController(db, undefined, config);
  router.post("/plants/:id/care-plan/sync", controller.sync);
  router.get("/care-tasks", controller.tasks);
  return router;
}
