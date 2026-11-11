import { Router } from "express";
import { z } from "zod";
import { ok } from "../middlewares/http.js";
import type { Config } from "../config/env.js";
import { providers } from "../services/providers.js";
export function weather(config: Config) {
  const router = Router();
  router.get("/forecast", async (req, res) => {
    const point = z
      .object({
        latitude: z.coerce.number().min(-90).max(90),
        longitude: z.coerce.number().min(-180).max(180),
      })
      .parse(req.query);
    ok(res, {
      isMock: config.MOCK_EXTERNAL_APIS,
      ...(await providers(config).forecast(point.latitude, point.longitude)),
    });
  });
  return router;
}
