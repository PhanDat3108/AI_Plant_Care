import { Router } from "express";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { authenticate } from "../middlewares/auth.js";
import { HttpError, success } from "../middlewares/errors.js";
import { gardenController } from "../controllers/garden.js";

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
  router.use(authenticate(config));
  router.get("/me", async (_req, res) => {
    const { id, displayName, isDemo } = res.locals.user;
    const profile = await db.profiles.upsert({
      where: { id },
      create: { id, display_name: displayName },
      update: {},
    });
    success(res, { ...profile, isDemo });
  });
  const garden = gardenController(db);
  router.get("/plants", garden.list);
  router.get("/plants/:id", garden.detail);
  return router;
}
