import { afterEach, expect, it, vi } from "vitest";
import express from "express";
import request from "supertest";
import { readConfig } from "../../src/config/env.js";
import type { Database } from "../../src/config/database.js";
import { internalReminderRoutes } from "../../src/routes/internal-reminders.js";
import { errors } from "../../src/middlewares/errors.js";
import { scheduledReminderService } from "../../src/services/scheduled-reminders.js";

const { runOnce } = vi.hoisted(() => ({ runOnce: vi.fn() }));
vi.mock("../../src/services/reminders.js", () => ({
  reminderService: () => ({ runOnce }),
}));
afterEach(() => vi.resetAllMocks());
const secret = "x".repeat(48);
function database(locked = true) {
  return {
    $transaction: vi.fn(async (callback) =>
      callback({ $queryRaw: vi.fn().mockResolvedValue([{ locked }]) }),
    ),
  } as unknown as Database;
}
function app(db: Database, key: string | undefined = secret) {
  const app = express();
  app.use(
    "/api/v1/internal/reminders",
    internalReminderRoutes(
      db,
      readConfig({
        NODE_ENV: "test",
        DATABASE_URL: "postgresql://test@localhost/test",
        CRON_SECRET: key,
      }),
    ),
  );
  app.use(errors);
  return app;
}
it("rejects missing/wrong secret without touching database", async () => {
  const db = database();
  for (const value of ["", "wrong"]) {
    await request(app(db))
      .post("/api/v1/internal/reminders/run")
      .set("X-Cron-Secret", value)
      .expect(401);
  }
  expect(db.$transaction).not.toHaveBeenCalled();
});
it("disabled until server secret is configured", async () => {
  const db = database();
  await request(app(db, ""))
    .post("/api/v1/internal/reminders/run")
    .set("X-Cron-Secret", secret)
    .expect(503);
  expect(db.$transaction).not.toHaveBeenCalled();
});
it("runs with cron secret without a user JWT", async () => {
  runOnce.mockResolvedValue({
    processed: 2,
    failed: 0,
    notifications_created: 1,
  });
  const r = await request(app(database()))
    .post("/api/v1/internal/reminders/run")
    .set("X-Cron-Secret", secret)
    .expect(200);
  expect(r.body.data.notifications_created).toBe(1);
  expect(r.headers["cache-control"]).toBe("no-store");
});
it("skips overlapping runs when database lock is held", async () => {
  expect(await scheduledReminderService(database(false)).run()).toEqual({
    skipped: true,
    reason: "ALREADY_RUNNING",
  });
  expect(runOnce).not.toHaveBeenCalled();
});
it("signals partial failure for scheduler monitoring", async () => {
  runOnce.mockResolvedValue({
    processed: 1,
    failed: 1,
    notifications_created: 0,
  });
  const r = await request(app(database()))
    .post("/api/v1/internal/reminders/run")
    .set("X-Cron-Secret", secret)
    .expect(503);
  expect(r.body.error.code).toBe("REMINDER_RUN_INCOMPLETE");
});

it("drains persisted pushes when no new reminders can run", async () => {
  const push = { run: vi.fn().mockResolvedValue({ sent: 1 }) };
  const result = await scheduledReminderService(database(false), push).run();
  expect(result).toMatchObject({ skipped: true, push: { sent: 1 } });
  expect(push.run).toHaveBeenCalledOnce();
});
it("drains pushes after a partial planner failure before reporting it", async () => {
  runOnce.mockResolvedValue({ processed: 0, failed: 1, notifications_created: 0 });
  const push = { run: vi.fn().mockResolvedValue({ sent: 1 }) };
  await expect(scheduledReminderService(database(), push).run()).rejects.toMatchObject({
    code: "REMINDER_RUN_INCOMPLETE",
  });
  expect(push.run).toHaveBeenCalledOnce();
});
