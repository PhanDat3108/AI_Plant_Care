import { afterAll, afterEach, expect, it, vi } from "vitest";
import request from "supertest";
import { createApp } from "../../src/app.js";
import { readConfig } from "../../src/config/env.js";
import { createDatabase } from "../../src/config/database.js";
const config = readConfig({
  NODE_ENV: "test",
  DATABASE_URL: "postgresql://test@localhost:1/test",
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_PUBLISHABLE_KEY: "test",
  AUTH_REDIRECT_URL: "http://localhost:3100/auth/callback",
  GOOGLE_AUTH_REDIRECT_URL: "vn.aiplantcare.app://auth/callback",
});
const db = createDatabase(config.DATABASE_URL);
const app = createApp(config, db);
afterEach(() => vi.unstubAllGlobals());
afterAll(() => db.$disconnect());
it("login returns session and never caches credentials", async () => {
  const f = vi.fn().mockResolvedValue(
    Response.json({
      access_token: "access",
      refresh_token: "refresh",
      token_type: "bearer",
    }),
  );
  vi.stubGlobal("fetch", f);
  const r = await request(app)
    .post("/api/v1/auth/login")
    .send({ email: "a@example.com", password: "password" })
    .expect(200);
  expect(r.body.data.access_token).toBe("access");
  expect(r.headers["cache-control"]).toBe("no-store");
  expect(String(f.mock.calls[0][0])).toContain("grant_type=password");
});
it("registration only accepts identity fields and hides account existence", async () => {
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue(Response.json({ id: "hidden" })),
  );
  const r = await request(app)
    .post("/api/v1/auth/register")
    .send({ email: "a@example.com", password: "password", full_name: "A" })
    .expect(200);
  expect(r.body.data.confirmation_required).toBe(true);
  expect(JSON.stringify(r.body)).not.toContain("hidden");
  await request(app)
    .post("/api/v1/auth/register")
    .send({
      email: "a@example.com",
      password: "password",
      full_name: "A",
      role: "admin",
    })
    .expect(400);
});
it("Google uses fixed callback and PKCE challenge", async () => {
  const r = await request(app)
    .post("/api/v1/auth/google")
    .send({ code_challenge: "a".repeat(43) })
    .expect(200);
  const url = new URL(r.body.data.url);
  expect(url.searchParams.get("redirect_to")).toBe(
    config.GOOGLE_AUTH_REDIRECT_URL,
  );
  expect(url.searchParams.get("code_challenge_method")).toBe("s256");
  await request(app)
    .post("/api/v1/auth/google")
    .send({
      code_challenge: "a".repeat(43),
      redirect_to: "https://evil.example",
    })
    .expect(400);
});
it("provider errors do not expose internals", async () => {
  vi.stubGlobal(
    "fetch",
    vi
      .fn()
      .mockResolvedValue(Response.json({ message: "secret" }, { status: 429 })),
  );
  const r = await request(app)
    .post("/api/v1/auth/login")
    .send({ email: "a@example.com", password: "password" })
    .expect(429);
  expect(JSON.stringify(r.body)).not.toContain("secret");
});
it("password reset and logout require verified token", async () => {
  await request(app)
    .post("/api/v1/auth/reset-password")
    .send({ password: "new-password" })
    .expect(401);
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue(new Response(null, { status: 401 })),
  );
  await request(app)
    .post("/api/v1/auth/logout")
    .set("Authorization", "Bearer forged")
    .expect(401);
});
it("recovery request uses configured callback", async () => {
  const f = vi.fn().mockResolvedValue(Response.json({}));
  vi.stubGlobal("fetch", f);
  await request(app)
    .post("/api/v1/auth/forgot-password")
    .send({ email: "a@example.com" })
    .expect(200);
  expect(
    new URL(String(f.mock.calls[0][0])).searchParams.get("redirect_to"),
  ).toBe(config.AUTH_REDIRECT_URL);
});

it("preserves AUTH_FAILED code for rejected credentials", async () => {
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue(Response.json({}, { status: 400 })),
  );
  const r = await request(app)
    .post("/api/v1/auth/login")
    .send({ email: "a@example.com", password: "wrong" })
    .expect(400);
  expect(r.body.error.code).toBe("AUTH_FAILED");
});

it.each([undefined, ""])(
  "Google falls back to email callback when separate URL is %s",
  async (callback) => {
    const legacyApp = createApp(
      { ...config, GOOGLE_AUTH_REDIRECT_URL: callback },
      db,
    );
    const r = await request(legacyApp)
      .post("/api/v1/auth/google")
      .send({ code_challenge: "a".repeat(43) })
      .expect(200);
    expect(new URL(r.body.data.url).searchParams.get("redirect_to")).toBe(
      config.AUTH_REDIRECT_URL,
    );
  },
);

it("missing both callback URLs returns a configuration error", async () => {
  const unconfigured = createApp(
    {
      ...config,
      GOOGLE_AUTH_REDIRECT_URL: undefined,
      AUTH_REDIRECT_URL: undefined,
    },
    db,
  );
  const r = await request(unconfigured)
    .post("/api/v1/auth/google")
    .send({ code_challenge: "a".repeat(43) })
    .expect(503);
  expect(r.body.error.code).toBe("AUTH_REDIRECT_NOT_CONFIGURED");
});
