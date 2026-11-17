import { Router } from "express";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { authenticate } from "../middlewares/auth.js";
import { authRoutes } from "./auth.js";
import { healthRoutes } from "./health.js";
import { profileRoutes } from "./profile.js";
import { gardenRoutes } from "./garden.js";
import { careDataRoutes } from "./care-data.js";
import { carePlanRoutes } from "./care-plan.js";
import { schedulesRoutes } from "./schedules.js";
import { notificationsRoutes } from "./notifications.js";

export function apiRoutes(db: Database, config: Config) {
  const router = Router();
  router.use(healthRoutes(db, config));
  router.use("/auth", authRoutes(config));
  router.use(authenticate(config));
  router.use("/me", profileRoutes(db));
  router.use(gardenRoutes(db));
  router.use(careDataRoutes(db, config));
  router.use(carePlanRoutes(db));
  router.use(schedulesRoutes(db));
  router.use(notificationsRoutes(db));
  return router;
}
