import type { RequestHandler } from "express";
import { z } from "zod";
import type { Database } from "../config/database.js";
import { success } from "../middlewares/errors.js";
import { scheduleService } from "../services/schedules.js";

const input = z.strictObject({
  interval_days: z.number().int().min(1).max(365),
  local_time: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
  enabled: z.boolean(),
});
export function scheduleController(db: Database): {
  list: RequestHandler;
  save: RequestHandler;
} {
  const service = scheduleService(db);
  return {
    async list(req, res) {
      success(
        res,
        await service.list(res.locals.user.id, z.uuid().parse(req.params.id)),
      );
    },
    async save(req, res) {
      success(
        res,
        await service.save(
          res.locals.user.id,
          z.uuid().parse(req.params.id),
          z.enum(["water", "fertilize"]).parse(req.params.kind),
          input.parse(req.body),
        ),
      );
    },
  };
}
