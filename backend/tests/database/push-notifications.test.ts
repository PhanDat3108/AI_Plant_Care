import "dotenv/config";
import { randomUUID } from "node:crypto";
import { beforeAll, afterAll, afterEach, expect, it, vi } from "vitest";
import request from "supertest";
import { createDatabase } from "../../src/config/database.js";
import { readConfig } from "../../src/config/env.js";
import { createApp } from "../../src/app.js";
import { pushDeviceService } from "../../src/services/push-devices.js";
import { pushNotificationService } from "../../src/services/push-notifications.js";

const db = createDatabase(process.env.DATABASE_URL!);
const users = [randomUUID(), randomUUID()];
const now = new Date();
const user = (id = users[0]) => ({
  id,
  displayName: "Push test",
  isDemo: false,
});
const registration = () => ({
  installation_id: randomUUID(),
  token: "test-token-" + randomUUID(),
  platform: "android" as const,
});
const devices = pushDeviceService(db);
beforeAll(async () => {
  await db.profiles.createMany({
    data: users.map((id) => ({ id, display_name: "Push test" })),
  });
});
afterEach(async () => {
  vi.unstubAllGlobals();
  await db.notifications.deleteMany({ where: { owner_id: { in: users } } });
  await db.push_devices.deleteMany({ where: { owner_id: { in: users } } });
  await db.plants.deleteMany({ where: { owner_id: { in: users } } });
});
afterAll(async () => {
  await db.profiles.deleteMany({ where: { id: { in: users } } });
  await db.$disconnect();
});
async function reminder(createdAt = now) {
  const plant = await db.plants.create({
    data: { owner_id: users[0], nickname: "Push fixture" },
  });
  const schedule = await db.care_schedules.create({
    data: {
      plant_id: plant.id,
      kind: "water",
      interval_days: 7,
      local_time: new Date("1970-01-01T08:00:00Z"),
    },
  });
  const task = await db.care_tasks.create({
    data: {
      plant_id: plant.id,
      schedule_id: schedule.id,
      kind: "water",
      original_due_at: createdAt,
      due_at: createdAt,
    },
  });
  const notification = await db.notifications.create({
    data: {
      owner_id: users[0],
      kind: "water",
      event_key: "care-task:" + task.id,
      title: "Tưới cây",
      body: "Kiểm tra đất",
      created_at: createdAt,
    },
  });
  return { notification, task };
}
it("enqueues per-device once and preserves the inbox after sending", async () => {
  await devices.register(user(), registration());
  await devices.register(user(), registration());
  await devices.register(user(users[1]), registration());
  const { notification } = await reminder();
  expect(await db.push_deliveries.count()).toBeGreaterThanOrEqual(2);
  expect(
    await db.push_deliveries.count({
      where: { notification_id: notification.id },
    }),
  ).toBe(2);
  await db.notifications.createMany({
    data: [{ ...notification, id: randomUUID() }],
    skipDuplicates: true,
  });
  const send = vi.fn(async () => "accepted");
  const runner = pushNotificationService(db, send, () => now);
  expect(await runner.run()).toMatchObject({ claimed: 2, sent: 2 });
  expect(await runner.run()).toMatchObject({ claimed: 0 });
  expect(send).toHaveBeenCalledTimes(2);
  expect(
    await db.notifications.findUnique({ where: { id: notification.id } }),
  ).toMatchObject({ read_at: null });
});
it("notification rollback rolls back queued deliveries", async () => {
  await devices.register(user(), registration());
  await expect(
    db.$transaction(async (tx) => {
      await tx.notifications.create({
        data: {
          owner_id: users[0],
          kind: "water",
          event_key: "care-task:" + randomUUID(),
          title: "Test",
          body: "Rollback",
        },
      });
      throw Error("rollback");
    }),
  ).rejects.toThrow("rollback");
  expect(
    await db.push_deliveries.count({ where: { owner_id: users[0] } }),
  ).toBe(0);
});
it("registration retries and token refresh preserve one installation", async () => {
  const input = registration();
  const first = await devices.register(user(), input);
  expect(await devices.register(user(), input)).toEqual(first);
  const { notification } = await reminder();
  const token = "refreshed-" + randomUUID();
  expect((await devices.register(user(), { ...input, token })).id).toBe(
    first.id,
  );
  const send = vi.fn(async () => "ok");
  await pushNotificationService(db, send, () => now).run();
  expect(send).toHaveBeenCalledWith(
    expect.objectContaining({
      token,
      data: expect.objectContaining({ notification_id: notification.id }),
    }),
  );
});
it("switching account cancels old deliveries and foreign deletion cannot remove a device", async () => {
  const input = registration();
  const old = await devices.register(user(), input);
  await reminder();
  expect(await devices.remove(users[1], old.id)).toEqual({ removed: false });
  const current = await devices.register(user(users[1]), input);
  expect(current.id).not.toBe(old.id);
  const send = vi.fn(async () => "ok");
  expect(
    await pushNotificationService(db, send, () => now).run(),
  ).toMatchObject({ claimed: 0 });
  expect(send).not.toHaveBeenCalled();
  expect(await devices.remove(users[1], current.id)).toEqual({ removed: true });
  expect(await devices.remove(users[1], current.id)).toEqual({
    removed: false,
  });
});
it("concurrent registration and cron runs cannot create duplicate deliveries", async () => {
  const input = registration();
  const results = await Promise.all([
    devices.register(user(), input),
    devices.register(user(), input),
  ]);
  expect(results[0].id).toBe(results[1].id);
  await reminder();
  const send = vi.fn(async () => "ok");
  const runner = pushNotificationService(db, send, () => now);
  const batches = await Promise.all([runner.run(), runner.run()]);
  expect(batches.reduce((sum, result) => sum + result.sent, 0)).toBe(1);
  expect(send).toHaveBeenCalledOnce();
});
it("retries transient failure after backoff with no new notifications", async () => {
  await devices.register(user(), registration());
  await reminder();
  const send = vi
    .fn()
    .mockRejectedValueOnce({ code: "messaging/server-unavailable" })
    .mockResolvedValue("ok");
  const runner = pushNotificationService(db, send, () => now);
  expect(await runner.run()).toMatchObject({ retry: 1 });
  expect(await runner.run()).toMatchObject({ claimed: 0 });
  expect(
    await pushNotificationService(
      db,
      send,
      () => new Date(now.getTime() + 61_000),
    ).run(),
  ).toMatchObject({ sent: 1 });
});
it("recovers abandoned leases but honors the attempt limit", async () => {
  await devices.register(user(), registration());
  await reminder();
  await db.push_deliveries.updateMany({
    where: { owner_id: users[0] },
    data: {
      status: "processing",
      attempts: 1,
      lease_id: randomUUID(),
      locked_until: new Date(now.getTime() - 1),
    },
  });
  const send = vi.fn(async () => "ok");
  expect(
    await pushNotificationService(db, send, () => now).run(),
  ).toMatchObject({ sent: 1 });
  await db.push_deliveries.updateMany({
    where: { owner_id: users[0] },
    data: {
      status: "processing",
      attempts: 8,
      locked_until: new Date(now.getTime() - 1),
    },
  });
  expect(
    await pushNotificationService(db, send, () => now).run(),
  ).toMatchObject({ claimed: 0 });
  expect(send).toHaveBeenCalledOnce();
});
it("invalidates expired FCM tokens, but protects tokens refreshed during a send", async () => {
  const input = registration();
  const device = await devices.register(user(), input);
  await reminder();
  const send = vi.fn(async () => {
    await devices.register(user(), {
      ...input,
      token: "new-token-" + randomUUID(),
    });
    throw { code: "messaging/registration-token-not-registered" };
  });
  expect(
    await pushNotificationService(db, send, () => now).run(),
  ).toMatchObject({ retry: 1 });
  expect(
    await db.push_devices.findUnique({ where: { id: device.id } }),
  ).toMatchObject({ active: true });
  const invalid = vi
    .fn()
    .mockRejectedValue({ code: "messaging/registration-token-not-registered" });
  expect(
    await pushNotificationService(
      db,
      invalid,
      () => new Date(now.getTime() + 61_000),
    ).run(),
  ).toMatchObject({ failed: 1 });
  expect(
    await db.push_devices.findUnique({ where: { id: device.id } }),
  ).toMatchObject({ active: false });
});
it("skips read/completed reminders and expires old notifications", async () => {
  await devices.register(user(), registration());
  const read = await reminder();
  await db.notifications.update({
    where: { id: read.notification.id },
    data: { read_at: now },
  });
  const complete = await reminder();
  await db.care_tasks.update({
    where: { id: complete.task.id },
    data: { state: "done" },
  });
  await reminder(new Date(now.getTime() - 25 * 60 * 60_000));
  const send = vi.fn(async () => "ok");
  expect(
    await pushNotificationService(db, send, () => now).run(),
  ).toMatchObject({ skipped: 2, sent: 0 });
  expect(send).not.toHaveBeenCalled();
});
it("HTTP registration validates bodies, uses authenticated owner, and returns no token", async () => {
  const config = readConfig({
    NODE_ENV: "test",
    DATABASE_URL: process.env.DATABASE_URL,
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_PUBLISHABLE_KEY: "test",
  });
  const app = createApp(config, db);
  const path = "/api/v1/notifications/devices";
  await request(app).post(path).send(registration()).expect(401);
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => Response.json({ id: users[0] })),
  );
  await request(app)
    .post(path)
    .set("Authorization", "Bearer test")
    .send({ ...registration(), owner_id: users[1] })
    .expect(400);
  const input = registration();
  const res = await request(app)
    .post(path)
    .set("Authorization", "Bearer test")
    .send(input)
    .expect(200);
  expect(JSON.stringify(res.body)).not.toContain(input.token);
  expect(
    await db.push_devices.findUnique({ where: { id: res.body.data.id } }),
  ).toMatchObject({ owner_id: users[0] });
  await request(app)
    .delete(path + "/" + res.body.data.id)
    .set("Authorization", "Bearer test")
    .expect(200);
});
it("disabled push does not claim or send pending deliveries", async () => {
  await devices.register(user(), registration());
  await reminder();
  expect(await pushNotificationService(db, null).run()).toMatchObject({
    enabled: false,
    claimed: 0,
  });
  expect(
    await db.push_deliveries.count({
      where: { owner_id: users[0], status: "pending" },
    }),
  ).toBe(1);
});
