import { renderAuthCallback } from "../views/auth-callback.js";
import { randomUUID } from "node:crypto";
import type { RequestHandler } from "express";

// Local backend diagnostic page, not a frontend application or a session store.
export const authCallback: RequestHandler = (_req, res) => {
  const nonce = randomUUID();
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader(
    "Content-Security-Policy",
    `default-src 'none'; script-src 'nonce-${nonce}'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'`,
  );
  res.type("html").send(renderAuthCallback(nonce));
};
