import type { RequestHandler } from "express";
import type { Config } from "../config/env.js";
import { HttpError } from "./errors.js";

export function requireCareReviewer(config: Config): RequestHandler {
  // Roles come from server configuration, never editable user_metadata.
  return (_req, res, next) => {
    if (
      res.locals.user.isDemo ||
      !config.CARE_REVIEWER_IDS.includes(res.locals.user.id)
    )
      throw new HttpError(
        403,
        "CARE_REVIEWER_REQUIRED",
        "Tài khoản chưa được cấp quyền duyệt dữ liệu loài.",
      );
    next();
  };
}
