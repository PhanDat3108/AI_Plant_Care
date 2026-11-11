import express from "express";
import cors from "cors";
import type { Config } from "./config/env.js";
import { authenticate } from "./middlewares/auth.js";
import { ok, HttpError, errors } from "./middlewares/http.js";
import { plants } from "./routes/plants.js";
import { scans } from "./routes/scans.js";
import { weather } from "./routes/weather.js";
import { care } from "./routes/care.js";
export function createApp(config: Config) {
  const app = express(),
    api = express.Router();
  app.disable("x-powered-by");
  app.use((req, res, next) => {
    const start = Date.now();
    res.on("finish", () =>
      console.info(
        req.method,
        req.path,
        res.statusCode,
        Date.now() - start + "ms",
      ),
    );
    next();
  });
  app.use(
    cors({ origin: config.CORS_ORIGINS }),
    express.json({ limit: "32kb" }),
  );
  api.get("/health", (_req, res) =>
    ok(res, {
      status: "ok",
      isMock: config.MOCK_EXTERNAL_APIS,
      demoAuth: config.DEV_AUTH_BYPASS,
    }),
  );
  api.use(authenticate(config));
  api.use("/plants", plants);
  api.use("/scans", scans(config));
  api.use("/care-schedules", care);
  api.use("/weather", weather(config));
  app.use("/api/v1", api);
  app.use(() => {
    throw new HttpError(404, "NOT_FOUND", "Đường dẫn chưa tồn tại.");
  });
  app.use(errors);
  return app;
}
