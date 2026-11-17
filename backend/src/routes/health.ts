import { Router } from "express";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { healthController } from "../controllers/health.js";

export function healthRoutes(db: Database, config: Config) {
  const router = Router();
  const controller = healthController(db, config);
  router.get("/health", controller.health);
  router.get("/ready", controller.ready);
  return router;
}
