import { authRoutes } from "./auth.js";
import { Router } from "express";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { authenticate } from "../middlewares/auth.js";
import { HttpError, success } from "../middlewares/errors.js";
import { gardenController } from "../controllers/garden.js";
import { profileController } from "../controllers/profile.js";

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
  return router;
}
