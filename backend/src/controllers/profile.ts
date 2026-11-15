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
} {
  const service = profileService(db);
  return {
    async get(_req, res) {
      const user = res.locals.user;
      success(res, { ...(await service.get(user)), isDemo: user.isDemo });
    },
    async update(req, res) {
      const user = res.locals.user;
      const changes = profileUpdate.parse(req.body);
      success(res, {
        ...(await service.update(user, changes)),
        isDemo: user.isDemo,
      });
    },
  };
}
