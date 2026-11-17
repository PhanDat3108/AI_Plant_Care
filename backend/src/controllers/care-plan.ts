import type { RequestHandler } from "express";
import { z } from "zod";
import type { Database } from "../config/database.js";
import { success } from "../middlewares/errors.js";
import { carePlanner } from "../services/care-planner.js";
import { dayBounds, localDate } from "../services/care-policy.js";
import {
  openMeteoProvider,
  type WeatherProvider,
} from "../services/weather.js";
export function carePlanController(
  db: Database,
  weather: WeatherProvider = openMeteoProvider(),
): { sync: RequestHandler; tasks: RequestHandler } {
  const planner = carePlanner(db, weather);
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
      const profile = await db.profiles.findUnique({
        where: { id: res.locals.user.id },
        select: { timezone: true },
      });
      const timezone = profile?.timezone ?? "Asia/Ho_Chi_Minh";
      const date = input.date ?? localDate(new Date(), timezone).toString();
      const { from, to } = dayBounds(date, timezone);
      const items = await db.care_tasks.findMany({
        where: {
          state: input.state,
          due_at: { gte: from, lt: to },
          care_schedules: {
            plants: { owner_id: res.locals.user.id },
            ...(input.state === "pending" ? { enabled: true } : {}),
          },
        },
        orderBy: [{ due_at: "asc" }, { id: "asc" }],
        take: input.limit,
        skip: input.offset,
        include: {
          care_schedules: {
            select: {
              plants: {
                select: {
                  id: true,
                  nickname: true,
                  cover_image_key: true,
                  reference_images: {
                    select: {
                      image_url: true,
                      attribution: true,
                      source_url: true,
                    },
                  },
                },
              },
            },
          },
        },
      });
      success(res, { date, timezone, items });
    },
  };
}
