import { Router } from "express";
import type { Database } from "../config/database.js";
import { profileController } from "../controllers/profile.js";

// Mounted at /me after authenticate(); the owner always comes from the verified token.
export function profileRoutes(db: Database) {
  const router = Router();
  const controller = profileController(db);
  router.get("/", controller.get);
  router.patch("/", controller.update);
  router.get("/stats", controller.stats);
  return router;
}
