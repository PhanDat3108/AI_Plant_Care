import { afterAll, expect, it } from "vitest";
import request from "supertest";
import { createApp } from "../../src/app.js";
import { readConfig } from "../../src/config/env.js";
import { createDatabase } from "../../src/config/database.js";
const db = createDatabase("postgresql://test@localhost:1/test");
const input = {
  DATABASE_URL: "postgresql://test@localhost:1/test",
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_PUBLISHABLE_KEY: "test",
};
afterAll(() => db.$disconnect());
it("development callback does not reflect code and disables caching", async () => {
  const app = createApp(readConfig({ ...input, NODE_ENV: "development" }), db);
  const r = await request(app)
    .get("/auth/callback?code=private-example-code")
    .expect(200);
  expect(r.text).not.toContain("private-example-code");
  expect(r.headers["cache-control"]).toBe("no-store");
  expect(r.headers["referrer-policy"]).toBe("no-referrer");
  expect(r.headers["content-security-policy"]).toContain(
    "frame-ancestors 'none'",
  );
  expect(r.text).toContain("history.replaceState");
});
it("diagnostic callback is not exposed in production", async () => {
  const app = createApp(readConfig({ ...input, NODE_ENV: "production" }), db);
  await request(app).get("/auth/callback").expect(404);
});
