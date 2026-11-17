import type { RequestHandler } from "express";

// Auth responses contain session credentials and must never be cached.
export const authNoStore: RequestHandler = (_req, res, next) => {
  res.setHeader("Cache-Control", "no-store");
  next();
};
