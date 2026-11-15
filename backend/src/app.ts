import { authCallback } from "./routes/auth-callback.js";
import { randomUUID } from "node:crypto";
import express from "express";
import cors from "cors";
import type { Config } from "./config/env.js";
import type { Database } from "./config/database.js";
import { apiRoutes } from "./routes/index.js";
import { errors, HttpError } from "./middlewares/errors.js";

export function createApp(config: Config, db: Database) {
  const app = express();
  app.disable("x-powered-by");
  app.use((req, res, next) => {
    const start = Date.now();
    res.locals.requestId = randomUUID();
    res.setHeader("X-Request-ID", res.locals.requestId);
    res.on("finish", () =>
      console.info(
        req.method,
        req.path,
        res.statusCode,
        Date.now() - start,
        res.locals.requestId,
      ),
    );
    next();
  });
  app.use(
    cors({ origin: config.CORS_ORIGINS }),
    express.json({ limit: "64kb" }),
  );
  if (config.NODE_ENV === "development")
    app.get("/auth/callback", authCallback);
  app.use("/api/v1", apiRoutes(db, config));
  app.use(() => {
    throw new HttpError(404, "NOT_FOUND", "Đường dẫn chưa tồn tại.");
  });
  app.use(errors);
  return app;
}
