import { Router } from "express";
import type { Database } from "../config/database.js";
import { gardenController } from "../controllers/garden.js";

export function gardenRoutes(db: Database) {
  const router = Router();
  const controller = gardenController(db);
  router.get("/plants", controller.list);
  router.get("/plants/:id", controller.detail);
  return router;
}
