import type { RequestHandler } from "express";
import { z } from "zod";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { success } from "../middlewares/errors.js";
import { carePlanner } from "../services/care-planner.js";
import { careTaskService } from "../services/care-tasks.js";
import {
  openMeteoProvider,
  type WeatherProvider,
} from "../services/weather.js";
export function carePlanController(
  db: Database,
  weather: WeatherProvider = openMeteoProvider(),
  config?: Config,
): { sync: RequestHandler; tasks: RequestHandler } {
  const planner = carePlanner(db, weather);
  const tasks = careTaskService(db, config);
  return {
    async sync(req, res) {
      z.strictObject({}).parse(req.body ?? {});
      success(
        res,
        await planner.sync(res.locals.user.id, z.uuid().parse(req.params.id)),
      );
    },
    async tasks(req, res) {
      const input = z
        .strictObject({
          date: z.iso.date().optional(),
          state: z.enum(["pending", "done", "skipped"]).default("pending"),
          limit: z.coerce.number().int().min(1).max(100).default(20),
          offset: z.coerce.number().int().min(0).max(100000).default(0),
        })
        .parse(req.query);
      success(res, await tasks.list(res.locals.user.id, input));
    },
  };
}
