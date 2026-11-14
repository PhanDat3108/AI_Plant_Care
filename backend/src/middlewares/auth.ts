import type { RequestHandler } from "express";
import { z } from "zod";
import type { Config } from "../config/env.js";
import { demoUserId } from "../config/demo.js";
import { HttpError } from "./errors.js";

const verifiedUser = z.object({
  id: z.uuid(),
  user_metadata: z
    .object({ full_name: z.string().optional() })
    .passthrough()
    .optional(),
});
export function authenticate(config: Config): RequestHandler {
  return async (req, res, next) => {
    if (config.NODE_ENV === "development" && config.DEV_AUTH_BYPASS) {
      res.locals.user = {
        id: demoUserId,
        displayName: "Người dùng demo",
        isDemo: true,
      };
      return next();
    }
    const token = req.get("authorization")?.match(/^Bearer (\S+)$/i)?.[1];
    if (!token) throw new HttpError(401, "UNAUTHORIZED", "Bạn cần đăng nhập.");
    if (!config.SUPABASE_URL || !config.SUPABASE_PUBLISHABLE_KEY) {
      throw new HttpError(
        503,
        "AUTH_UNAVAILABLE",
        "Chưa cấu hình Supabase Auth.",
      );
    }
    try {
      const response = await fetch(
        new URL("/auth/v1/user", config.SUPABASE_URL),
        {
          headers: {
            apikey: config.SUPABASE_PUBLISHABLE_KEY,
            Authorization: "Bearer " + token,
          },
          signal: AbortSignal.timeout(8000),
        },
      );
      if ([401, 403].includes(response.status)) {
        throw new HttpError(
          401,
          "UNAUTHORIZED",
          "Phiên đăng nhập không hợp lệ.",
        );
      }
      if (!response.ok) throw new Error("Auth provider unavailable");
      const user = verifiedUser.parse(await response.json());
      res.locals.user = {
        id: user.id,
        displayName:
          user.user_metadata?.full_name?.trim().slice(0, 100) || "Người dùng",
        isDemo: false,
      };
    } catch (error) {
      if (error instanceof HttpError) throw error;
      throw new HttpError(
        503,
        "AUTH_UNAVAILABLE",
        "Chưa kết nối được dịch vụ xác thực.",
      );
    }
    next();
  };
}
