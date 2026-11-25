import type { RequestHandler } from "express";
import { z } from "zod";
import type { Database } from "../config/database.js";
import { HttpError, success } from "../middlewares/errors.js";
import { pushDeviceService } from "../services/push-devices.js";

const registration = z.strictObject({
  installation_id: z.uuid(),
  token: z.string().trim().min(20).max(4096).regex(/^\S+$/),
  platform: z.enum(["android", "ios"]),
});

export function pushDeviceController(db: Database): {
  register: RequestHandler;
  remove: RequestHandler;
} {
  const service = pushDeviceService(db);
  return {
    async register(req, res) {
      if (res.locals.user.isDemo) {
        throw new HttpError(
          403,
          "REAL_AUTH_REQUIRED",
          "Đăng nhập tài khoản thật để nhận push.",
        );
      }
      res.setHeader("Cache-Control", "no-store");
      success(
        res,
        await service.register(res.locals.user, registration.parse(req.body)),
      );
    },
    async remove(req, res) {
      res.setHeader("Cache-Control", "no-store");
      success(
        res,
        await service.remove(res.locals.user.id, z.uuid().parse(req.params.id)),
      );
    },
  };
}
