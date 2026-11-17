import { Router } from "express";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { careDataController } from "../controllers/care-data.js";
import { requireCareReviewer } from "../middlewares/care-reviewer.js";

export function careDataRoutes(db: Database, config: Config) {
  const router = Router();
  const controller = careDataController(db, config);
  const reviewer = requireCareReviewer(config);
  router.get("/plants/:id/care-data", controller.readPlant);
  router.post("/plants/:id/care-data/enrich", controller.enrichPlant);
  router.get("/species/:id/care-data", reviewer, controller.readSpecies);
  router.post(
    "/species/:id/care-data/enrich",
    reviewer,
    controller.enrichSpecies,
  );
  router.patch(
    "/species/:id/care-data/review",
    reviewer,
    controller.reviewSpecies,
  );
  return router;
}
