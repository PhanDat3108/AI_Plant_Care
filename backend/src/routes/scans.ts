import { Router } from "express";
import multer from "multer";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { scansController } from "../controllers/scans.js";

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // Giới hạn 10MB
});

export function scansRoutes(db: Database, config: Config): Router {
  const router = Router();
  const controller = scansController(db, config);

  router.post("/scans", upload.single("image"), controller.create);
  router.get("/scans", controller.list);
  router.get("/scans/:id", controller.getById);
  router.delete("/scans/:id", controller.remove);

  return router;
}
