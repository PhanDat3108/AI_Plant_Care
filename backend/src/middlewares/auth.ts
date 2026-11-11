import type { RequestHandler } from "express";
import { z } from "zod";
import type { Config } from "../config/env.js";
import { demoUserId } from "../config/demo.js";
import { HttpError } from "./http.js";

export function authenticate(config: Config): RequestHandler {
  return async (req, res, next) => {
    if (config.NODE_ENV === "development" && config.DEV_AUTH_BYPASS) {
      res.locals.ownerId = demoUserId;
      return next();
    }
    const token = req.get("authorization")?.match(/^Bearer (\S+)$/i)?.[1];
    if (!token) throw new HttpError(401, "UNAUTHORIZED", "Bạn cần đăng nhập.");
    if (!config.SUPABASE_URL || !config.SUPABASE_PUBLISHABLE_KEY)
      throw new HttpError(
        503,
        "AUTH_UNAVAILABLE",
        "Chưa cấu hình Supabase Auth.",
      );
    let response: globalThis.Response;
    try {
      response = await fetch(new URL("/auth/v1/user", config.SUPABASE_URL), {
        headers: {
          apikey: config.SUPABASE_PUBLISHABLE_KEY,
          Authorization: "Bearer " + token,
        },
        signal: AbortSignal.timeout(8000),
      });
    } catch {
      throw new HttpError(
        503,
        "AUTH_UNAVAILABLE",
        "Không kết nối được Supabase Auth.",
      );
    }
    if (response.status === 401 || response.status === 403)
      throw new HttpError(401, "UNAUTHORIZED", "Phiên đăng nhập chưa hợp lệ.");
    if (!response.ok)
      throw new HttpError(
        503,
        "AUTH_UNAVAILABLE",
        "Supabase Auth chưa sẵn sàng.",
      );
    res.locals.ownerId = z
      .object({ id: z.uuid() })
      .parse(await response.json()).id;
    next();
  };
}
