import type { RequestHandler } from "express";
import { z } from "zod";
import type { Config } from "../config/env.js";
import type { Database } from "../config/database.js";
import { HttpError, success } from "../middlewares/errors.js";
import { careDataService } from "../services/care-data.js";
import {
  generationInputSchema,
  reviewInputSchema,
} from "../services/care-data-schema.js";
import {
  createCareProvider,
  type CareProvider,
} from "../services/gemini-care.js";

export function careDataController(
  db: Database,
  config: Config,
  provider: CareProvider = createCareProvider(config),
) {
  const service = careDataService(db, provider);
  // Roles come from server configuration, never editable Supabase user_metadata.
  const requireReviewer: RequestHandler = (_req, res, next) => {
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
  const readPlant: RequestHandler = async (req, res) => {
    success(
      res,
      await service.readForPlant(
        res.locals.user.id,
        z.uuid().parse(req.params.id),
      ),
    );
  };
  const enrichPlant: RequestHandler = async (req, res) => {
    z.strictObject({}).parse(req.body ?? {});
    const result = await service.enrichForPlant(
      res.locals.user.id,
      z.uuid().parse(req.params.id),
    );
    if (result.draft?.status === "generating") res.status(202);
    success(res, result);
  };
  const readSpecies: RequestHandler = async (req, res) => {
    success(res, await service.read(z.uuid().parse(req.params.id), true));
  };
  const enrichSpecies: RequestHandler = async (req, res) => {
    const result = await service.generate(
      z.uuid().parse(req.params.id),
      generationInputSchema.parse(req.body ?? {}),
    );
    if (result.draft?.status === "generating") res.status(202);
    success(res, result);
  };
  const reviewSpecies: RequestHandler = async (req, res) => {
    success(
      res,
      await service.review(
        z.uuid().parse(req.params.id),
        res.locals.user.id,
        reviewInputSchema.parse(req.body),
      ),
    );
  };
  return {
    requireReviewer,
    readPlant,
    enrichPlant,
    readSpecies,
    enrichSpecies,
    reviewSpecies,
  };
}
