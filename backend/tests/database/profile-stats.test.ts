import "dotenv/config";
import { randomUUID } from "node:crypto";
import { afterAll, afterEach, beforeAll, expect, it, vi } from "vitest";
import request from "supertest";
import { createDatabase } from "../../src/config/database.js";
import { readConfig } from "../../src/config/env.js";
import { createApp } from "../../src/app.js";

const db = createDatabase(process.env.DATABASE_URL!);
const owner = randomUUID(),
  other = randomUUID(),
  empty = randomUUID();
const app = createApp(
  readConfig({
    NODE_ENV: "test",
    DATABASE_URL: process.env.DATABASE_URL,
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_PUBLISHABLE_KEY: "test",
  }),
  db,
);
const headers = { Authorization: "Bearer test" };
const last = "2020-01-03T08:00:00.000Z";
function auth(id = owner) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => Response.json({ id, email: "profile@example.com" })),
  );
}
beforeAll(async () => {
  await db.profiles.createMany({
    data: [owner, other, empty].map((id) => ({ id, display_name: "Fixture" })),
  });
  const a = await db.plants.create({
    data: { owner_id: owner, nickname: "A" },
  });
  const b = await db.plants.create({
    data: { owner_id: other, nickname: "B" },
  });
  await db.care_logs.createMany({
    data: [
      ...["water", "water", "fertilize", "treat"].map((kind) => ({
        plant_id: a.id,
        kind,
        request_id: randomUUID(),
        performed_at: new Date(last),
      })),
      {
        plant_id: a.id,
        kind: "note",
        request_id: randomUUID(),
        performed_at: new Date("2020-02-01"),
      },
      {
        plant_id: a.id,
        kind: "water",
        request_id: randomUUID(),
        performed_at: new Date("2099-01-01"),
      },
      {
        plant_id: b.id,
        kind: "water",
        request_id: randomUUID(),
        performed_at: new Date("2020-03-01"),
      },
    ],
  });
});
afterEach(() => vi.unstubAllGlobals());
afterAll(async () => {
  await db.profiles.deleteMany({
    where: { id: { in: [owner, other, empty] } },
  });
  await db.$disconnect();
});
it("profile and stats count only own completed care logs, not notes or future entries", async () => {
  auth();
  const expected = {
    total_actions: 4,
    watering_count: 2,
    fertilizing_count: 1,
    treatment_count: 1,
    last_cared_at: last,
  };
  for (const path of ["/api/v1/me", `/api/v1/me/stats?user_id=${other}`]) {
    const r = await request(app).get(path).set(headers).expect(200);
    expect(r.body.data.care_stats).toEqual(expected);
    expect(r.body.data.total_plants).toBe(1);
    expect(r.body.data.total_ai_scans).toBe(0);
  }
});
it("empty profiles return zero counters and a null last care date", async () => {
  auth(empty);
  const r = await request(app).get("/api/v1/me/stats").set(headers).expect(200);
  expect(r.body.data).toEqual({
    total_plants: 0,
    total_ai_scans: 0,
    care_stats: {
      total_actions: 0,
      watering_count: 0,
      fertilizing_count: 0,
      treatment_count: 0,
      last_cared_at: null,
    },
  });
  await request(app).get("/api/v1/me/stats").expect(401);
});
it("switching accounts cannot expose the previous account's care totals", async () => {
  auth(other);
  const r = await request(app).get("/api/v1/me/stats").set(headers).expect(200);
  expect(r.body.data.care_stats.total_actions).toBe(1);
  expect(r.body.data.care_stats.fertilizing_count).toBe(0);
});
