import "dotenv/config";
import { randomUUID } from "node:crypto";
import { beforeAll, afterAll, afterEach, it, expect, vi } from "vitest";
import request from "supertest";
import { createDatabase } from "../../src/config/database.js";
import { carePlanner } from "../../src/services/care-planner.js";
import { scheduleService } from "../../src/services/schedules.js";
import { createApp } from "../../src/app.js";
import { readConfig } from "../../src/config/env.js";
import type { Forecast } from "../../src/services/weather.js";
const db = createDatabase(process.env.DATABASE_URL!);
const owner = randomUUID(),
  other = randomUUID(),
  species = randomUUID();
const app = createApp(
  readConfig({
    NODE_ENV: "test",
    DATABASE_URL: process.env.DATABASE_URL,
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_PUBLISHABLE_KEY: "test",
  }),
  db,
);
const now = new Date("2026-11-16T00:00:00Z");
const forecast = vi
  .fn<() => Promise<Forecast | null>>()
  .mockImplementation(async () => null);
const planner = carePlanner(db, { forecast }, () => now);
beforeAll(async () => {
  await db.profiles.createMany({
    data: [
      { id: owner, display_name: "Planner owner" },
      { id: other, display_name: "Other" },
    ],
  });
  await db.plant_species.create({
    data: {
      id: species,
      scientific_name: "Planner fixture " + species,
      watering_days: 7,
      fertilizing_days: 14,
      care_status: "verified",
      care_reviewed_at: new Date(),
    },
  });
});
afterEach(() => {
  forecast.mockReset();
  forecast.mockResolvedValue(null);
  vi.unstubAllGlobals();
});
afterAll(async () => {
  await db.profiles.deleteMany({ where: { id: { in: [owner, other] } } });
  await db.plant_species.delete({ where: { id: species } });
  await db.$disconnect();
});
async function plant(environment = "outdoor", known = true, location = true) {
  return db.plants.create({
    data: {
      owner_id: owner,
      nickname: "Fixture",
      species_id: known ? species : null,
      environment,
      ...(location ? { latitude: 10, longitude: 106 } : {}),
    },
  });
}
it("initializes from species once and preserves manually configured rules", async () => {
  const p = await plant();
  const first = await planner.sync(owner, p.id);
  const second = await planner.sync(owner, p.id);
  expect(first.tasks).toHaveLength(2);
  expect(second.tasks.map((t) => t.id)).toEqual(first.tasks.map((t) => t.id));
  expect(
    first.tasks.find((t) => t.kind === "water")?.due_at.toISOString(),
  ).toBe("2026-11-23T01:00:00.000Z");
  await scheduleService(db).save(owner, p.id, "water", {
    interval_days: 3,
    local_time: "09:00",
    enabled: false,
  });
  const after = await planner.sync(owner, p.id);
  expect(after.tasks).toHaveLength(1);
  expect(
    (
      await db.care_schedules.findUniqueOrThrow({
        where: { plant_id_kind: { plant_id: p.id, kind: "water" } },
      })
    ).interval_days,
  ).toBe(3);
});
it("unknown species skips automatic rules, missing location safely uses baseline", async () => {
  const unknown = await plant("unknown", false, false);
  const r = await planner.sync(owner, unknown.id);
  expect(r.tasks).toHaveLength(0);
  expect(r.warnings).toContain("MISSING_WATER_INTERVAL");
  expect(forecast).not.toHaveBeenCalled();
  const missing = await plant("outdoor", true, false);
  const baseline = await planner.sync(owner, missing.id);
  expect(baseline.tasks).toHaveLength(2);
  expect(baseline.warnings).toContain("LOCATION_REQUIRED_FOR_WEATHER");
});
it("rain adjustment is bounded, outages preserve it, repeated sync creates no duplicates", async () => {
  const p = await plant();
  await planner.sync(owner, p.id);
  await db.care_schedules.updateMany({
    where: { plant_id: p.id },
    data: { starts_at: new Date("2026-11-10T00:00:00Z") },
  });
  forecast.mockResolvedValue({
    source: "open-meteo",
    timezone: "Asia/Ho_Chi_Minh",
    fetched_at: now.toISOString(),
    days: [
      {
        date: "2026-11-17",
        rain_mm: 8,
        rain_probability: 90,
        temperature_max_c: 28,
      },
    ],
  });
  const one = await planner.sync(owner, p.id);
  const two = await planner.sync(owner, p.id);
  const task = one.tasks.find((t) => t.kind === "water")!;
  expect(task.original_due_at.toISOString()).toBe("2026-11-17T01:00:00.000Z");
  expect(task.due_at.toISOString()).toBe("2026-11-18T01:00:00.000Z");
  expect(two.tasks.find((t) => t.kind === "water")?.due_at).toEqual(
    task.due_at,
  );
  forecast.mockResolvedValue(null);
  const offline = await planner.sync(owner, p.id);
  expect(offline.tasks.find((t) => t.kind === "water")?.due_at).toEqual(
    task.due_at,
  );
  expect(offline.warnings).toContain("WEATHER_UNAVAILABLE_KEEP_EXISTING_DUE");
  await db.plants.update({
    where: { id: p.id },
    data: { environment: "indoor" },
  });
  const indoor = await planner.sync(owner, p.id);
  expect(indoor.tasks.find((t) => t.kind === "water")?.due_at).toEqual(
    task.original_due_at,
  );
  expect(
    indoor.tasks.find((t) => t.kind === "water")?.adjustment_reason,
  ).toBeNull();
});
it("due tasks write inbox only once, care log advances next cycle, history survives plant deletion", async () => {
  const p = await plant("indoor");
  await planner.sync(owner, p.id);
  await db.care_schedules.updateMany({
    where: { plant_id: p.id, kind: "water" },
    data: { starts_at: new Date("2026-11-08T00:00:00Z") },
  });
  const results = await Promise.all([
    planner.sync(owner, p.id),
    planner.sync(owner, p.id),
  ]);
  expect(results.reduce((sum, r) => sum + r.notifications_created, 0)).toBe(1);
  const task = results[0].tasks.find((t) => t.kind === "water")!;
  const key = `care-task:${task.id}`;
  expect(
    await db.notifications.count({
      where: { owner_id: owner, event_key: key },
    }),
  ).toBe(1);
  await db.$transaction(async (tx) => {
    await tx.care_tasks.update({
      where: { id: task.id },
      data: { state: "done" },
    });
    await tx.care_logs.create({
      data: {
        plant_id: p.id,
        task_id: task.id,
        request_id: randomUUID(),
        kind: "water",
        performed_at: now,
      },
    });
  });
  const next = await planner.sync(owner, p.id);
  expect(
    next.tasks.find((t) => t.kind === "water")?.original_due_at.toISOString(),
  ).toBe("2026-11-23T01:00:00.000Z");
  await db.plants.delete({ where: { id: p.id } });
  expect(
    await db.notifications.count({
      where: { owner_id: owner, event_key: key },
    }),
  ).toBe(1);
});
it("manual toggle on the same day restores one occurrence, never duplicates it", async () => {
  const p = await plant("indoor");
  await planner.sync(owner, p.id);
  const service = scheduleService(db);
  const body = { interval_days: 7, local_time: "08:00", enabled: false };
  await service.save(owner, p.id, "water", body);
  await service.save(owner, p.id, "water", { ...body, enabled: true });
  const one = await planner.sync(owner, p.id);
  const two = await planner.sync(owner, p.id);
  expect(one.tasks.find((t) => t.kind === "water")?.id).toBe(
    two.tasks.find((t) => t.kind === "water")?.id,
  );
  expect(
    await db.care_tasks.count({
      where: { plant_id: p.id, kind: "water", state: "pending" },
    }),
  ).toBe(1);
});
it("other owner cannot trigger weather access or read tasks; date validation enforced", async () => {
  const p = await plant();
  await expect(planner.sync(other, p.id)).rejects.toMatchObject({
    status: 404,
  });
  expect(forecast).not.toHaveBeenCalled();
  vi.stubGlobal(
    "fetch",
    vi.fn().mockImplementation(async () => Response.json({ id: other })),
  );
  await request(app)
    .post(`/api/v1/plants/${p.id}/care-plan/sync`)
    .set("Authorization", "Bearer test")
    .send({})
    .expect(404);
  const tasks = await request(app)
    .get("/api/v1/care-tasks?date=2026-11-23")
    .set("Authorization", "Bearer test")
    .expect(200);
  expect(tasks.body.data.items).toHaveLength(0);
  await request(app)
    .get("/api/v1/care-tasks?date=2026-02-30")
    .set("Authorization", "Bearer test")
    .expect(400);
});
