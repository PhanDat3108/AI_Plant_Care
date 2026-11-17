import type { RequestHandler } from "express";
import { z } from "zod";
import type { Database } from "../config/database.js";
import { success } from "../middlewares/errors.js";
import { profileService } from "../services/profile.js";

const profileUpdate = z
  .strictObject({
    display_name: z.string().trim().min(1).max(100).optional(),
    timezone: z
      .string()
      .trim()
      .min(1)
      .max(100)
      .refine((value) => {
        try {
          new Intl.DateTimeFormat("en-US", { timeZone: value });
          return true;
        } catch {
          return false;
        }
      })
      .optional(),
  })
  .refine((value) => Object.keys(value).length > 0);

export function profileController(db: Database): {
  get: RequestHandler;
  update: RequestHandler;
  stats: RequestHandler;
} {
  const service = profileService(db);
  return {
    async stats(_req, res) {
      success(res, await service.stats(res.locals.user.id));
    },
    async get(_req, res) {
      success(res, await service.get(res.locals.user));
    },
    async update(req, res) {
      const changes = profileUpdate.parse(req.body);
      success(res, await service.update(res.locals.user, changes));
    },
  };
}
