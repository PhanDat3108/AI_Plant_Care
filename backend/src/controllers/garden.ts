import type { RequestHandler } from "express";
import { z } from "zod";
import type { Database } from "../config/database.js";
import { gardenService } from "../services/garden.js";
import { success } from "../middlewares/errors.js";

export function gardenController(db: Database): {
  list: RequestHandler;
  detail: RequestHandler;
} {
  const service = gardenService(db);
  return {
    async list(req, res) {
      const { offset, limit } = z
        .object({
          offset: z.coerce.number().int().min(0).max(100000).default(0),
          limit: z.coerce.number().int().min(1).max(100).default(20),
        })
        .parse(req.query);
      success(res, await service.list(res.locals.user.id, offset, limit));
    },
    async detail(req, res) {
      success(
        res,
        await service.detail(res.locals.user.id, z.uuid().parse(req.params.id)),
      );
    },
  };
}
