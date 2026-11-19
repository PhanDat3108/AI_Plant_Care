import type { RequestHandler } from "express";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { success } from "../middlewares/errors.js";
import { healthService } from "../services/health.js";

export function healthController(
  db: Database,
  config: Config,
): {
  health: RequestHandler;
  ready: RequestHandler;
} {
  const service = healthService(db);
  return {
    health(_req, res) {
      success(res, { status: "ok", demoAuth: config.DEV_AUTH_BYPASS });
    },
    async ready(_req, res) {
      success(res, await service.ready());
    },
  };
}
