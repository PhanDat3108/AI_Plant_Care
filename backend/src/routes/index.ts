import { carePlanController } from "../controllers/care-plan.js";
import { scheduleController } from "../controllers/schedules.js";
import { notificationController } from "../controllers/notifications.js";
import { authRoutes } from "./auth.js";
import { Router } from "express";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { authenticate } from "../middlewares/auth.js";
import { HttpError, success } from "../middlewares/errors.js";
import { gardenController } from "../controllers/garden.js";
import { profileController } from "../controllers/profile.js";
import { careDataController } from "../controllers/care-data.js";

export function apiRoutes(db: Database, config: Config) {
  const router = Router();
  router.get("/health", (_req, res) =>
    success(res, { status: "ok", demoAuth: config.DEV_AUTH_BYPASS }),
  );
  router.get("/ready", async (_req, res) => {
    try {
      await db.profiles.count();
    } catch {
      throw new HttpError(
        503,
        "DATABASE_UNAVAILABLE",
        "Database chưa sẵn sàng hoặc chưa migrate.",
      );
    }
    success(res, { status: "ready" });
  });
  router.use("/auth", authRoutes(config));
  router.use(authenticate(config));
  const profile = profileController(db);
  router.get("/me", profile.get);
  router.patch("/me", profile.update);
  const garden = gardenController(db);
  router.get("/plants", garden.list);
  router.get("/plants/:id", garden.detail);
  const careData = careDataController(db, config);
  router.get("/plants/:id/care-data", careData.readPlant);
  router.post("/plants/:id/care-data/enrich", careData.enrichPlant);
  router.get(
    "/species/:id/care-data",
    careData.requireReviewer,
    careData.readSpecies,
  );
  router.post(
    "/species/:id/care-data/enrich",
    careData.requireReviewer,
    careData.enrichSpecies,
  );
  router.patch(
    "/species/:id/care-data/review",
    careData.requireReviewer,
    careData.reviewSpecies,
  );
  const care = carePlanController(db);
  router.post("/plants/:id/care-plan/sync", care.sync);
  router.get("/care-tasks", care.tasks);
  const schedules = scheduleController(db);
  router.get("/plants/:id/schedules", schedules.list);
  router.put("/plants/:id/schedules/:kind", schedules.save);
  const notifications = notificationController(db);
  router.get("/notifications", notifications.list);
  router.get("/notifications/unread-count", notifications.unreadCount);
  router.patch("/notifications/:id/read", notifications.markRead);
  return router;
}
