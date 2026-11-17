import "dotenv/config";
import { randomUUID } from "node:crypto";
import {
  afterAll,
  beforeAll,
  beforeEach,
  afterEach,
  expect,
  it,
  vi,
} from "vitest";
import request from "supertest";
import { createDatabase } from "../../src/config/database.js";
import { readConfig } from "../../src/config/env.js";
import { createApp } from "../../src/app.js";
const db = createDatabase(process.env.DATABASE_URL!);
const a = randomUUID(),
  b = randomUUID(),
  plant = randomUUID(),
  otherPlant = randomUUID();
const app = createApp(
  readConfig({
    NODE_ENV: "test",
    DATABASE_URL: process.env.DATABASE_URL,
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_PUBLISHABLE_KEY: "test",
  }),
  db,
);
const h = { Authorization: "Bearer test-token" };
function auth(
  id = a,
  metadata: unknown = { picture: "https://example.com/google-avatar.jpg" },
) {
  vi.stubGlobal(
    "fetch",
    vi.fn().mockImplementation(async () =>
      Response.json({
        id,
        email: "verified@example.com",
        user_metadata: metadata,
      }),
    ),
  );
}
beforeAll(async () => {
  await db.profiles.createMany({
    data: [
      { id: a, display_name: "A" },
      { id: b, display_name: "B" },
    ],
  });
  await db.plants.createMany({
    data: [
      { id: plant, owner_id: a, nickname: "Cây A" },
      { id: otherPlant, owner_id: b, nickname: "Cây B" },
    ],
  });
  await db.scans.createMany({
    data: [
      {
        owner_id: a,
        request_id: randomUUID(),
        image_key: "test/a.jpg",
        mode: "both",
        source: "fixture",
        is_mock: true,
        health_status: "unknown",
      },
      {
        owner_id: b,
        request_id: randomUUID(),
        image_key: "test/b.jpg",
        mode: "both",
        source: "fixture",
        is_mock: true,
        health_status: "healthy",
      },
    ],
  });
});
beforeEach(() => auth());
afterEach(() => vi.unstubAllGlobals());
afterAll(async () => {
  await db.profiles.deleteMany({ where: { id: { in: [a, b] } } });
  await db.$disconnect();
});
it("profile supplies verified email/avatar and only owner's totals", async () => {
  const r = await request(app).get("/api/v1/me").set(h).expect(200);
  expect(r.body.data).toMatchObject({
    id: a,
    email: "verified@example.com",
    avatar_url: "https://example.com/google-avatar.jpg",
    total_plants: 1,
    total_ai_scans: 1,
  });
  auth(a, { picture: "javascript:alert(1)", email: "fake@example.com" });
  const safe = await request(app).get("/api/v1/me").set(h).expect(200);
  expect(safe.body.data.avatar_url).toBeNull();
  expect(safe.body.data.email).toBe("verified@example.com");
});
it("schedule read/edit is owned, idempotent, validates real HH:mm", async () => {
  const path = `/api/v1/plants/${plant}/schedules/water`;
  const body = { interval_days: 7, local_time: "08:30", enabled: true };
  const first = await request(app).put(path).set(h).send(body).expect(200);
  const again = await request(app).put(path).set(h).send(body).expect(200);
  expect(again.body.data.id).toBe(first.body.data.id);
  expect(again.body.data.local_time).toBe("08:30");
  const list = await request(app)
    .get(`/api/v1/plants/${plant}/schedules`)
    .set(h)
    .expect(200);
  expect(list.body.data.timezone).toBe("Asia/Ho_Chi_Minh");
  expect(list.body.data.items).toHaveLength(1);
  for (const changes of [
    { interval_days: 0 },
    { local_time: "24:00" },
    { local_time: "8:00" },
    { enabled: "false" },
    { owner_id: b },
  ])
    await request(app)
      .put(path)
      .set(h)
      .send({ ...body, ...changes })
      .expect(400);
  auth(b);
  await request(app)
    .get(`/api/v1/plants/${plant}/schedules`)
    .set(h)
    .expect(404);
  await request(app).put(path).set(h).send(body).expect(404);
});
it("changing or disabling a rule invalidates only pending tasks, retry is harmless", async () => {
  const path = `/api/v1/plants/${plant}/schedules/fertilize`;
  const body = { interval_days: 14, local_time: "09:00", enabled: true };
  const r = await request(app).put(path).set(h).send(body).expect(200);
  const schedule = r.body.data.id;
  const pending = await db.care_tasks.create({
    data: {
      schedule_id: schedule,
      plant_id: plant,
      kind: "fertilize",
      original_due_at: new Date("2026-01-01T02:00:00Z"),
      due_at: new Date("2026-01-01T02:00:00Z"),
    },
  });
  const done = await db.care_tasks.create({
    data: {
      schedule_id: schedule,
      plant_id: plant,
      kind: "fertilize",
      original_due_at: new Date("2026-01-02T02:00:00Z"),
      due_at: new Date("2026-01-02T02:00:00Z"),
      state: "done",
    },
  });
  await request(app).put(path).set(h).send(body).expect(200);
  expect(
    (await db.care_tasks.findUniqueOrThrow({ where: { id: pending.id } }))
      .state,
  ).toBe("pending");
  await request(app)
    .put(path)
    .set(h)
    .send({ ...body, enabled: false })
    .expect(200);
  expect(
    (await db.care_tasks.findUniqueOrThrow({ where: { id: pending.id } }))
      .state,
  ).toBe("skipped");
  expect(
    (await db.care_tasks.findUniqueOrThrow({ where: { id: done.id } })).state,
  ).toBe("done");
  await request(app).put(path).set(h).send(body).expect(200);
  expect(
    (await db.care_tasks.findUniqueOrThrow({ where: { id: pending.id } }))
      .state,
  ).toBe("skipped");
});
it("concurrent schedule writes keep a single rule per plant/kind", async () => {
  const results = await Promise.all(
    [3, 5].map((interval_days) =>
      request(app)
        .put(`/api/v1/plants/${otherPlant}/schedules/water`)
        .set(h)
        .send({ interval_days, local_time: "08:00", enabled: true }),
    ),
  );
  // A may not edit B's plant even under simultaneous requests.
  expect(results.map((r) => r.status)).toEqual([404, 404]);
  const own = await Promise.all(
    [3, 5].map((interval_days) =>
      request(app)
        .put(`/api/v1/plants/${plant}/schedules/water`)
        .set(h)
        .send({ interval_days, local_time: "08:00", enabled: true }),
    ),
  );
  expect(own.map((r) => r.status)).toEqual([200, 200]);
  expect(
    await db.care_schedules.count({
      where: { plant_id: plant, kind: "water" },
    }),
  ).toBe(1);
});
it("notifications page correctly on timestamp ties, never leak other owner", async () => {
  const at = new Date("2026-11-01T01:00:00.123Z");
  await db.notifications.createMany({
    data: [
      ...Array.from({ length: 3 }, (_, i) => ({
        owner_id: a,
        kind: "water",
        title: `A ${i}`,
        body: "Nội dung",
        created_at: at,
      })),
      {
        owner_id: b,
        kind: "system",
        title: "PRIVATE B",
        body: "private",
        created_at: at,
      },
    ],
  });
  const first = await request(app)
    .get("/api/v1/notifications?limit=2")
    .set(h)
    .expect(200);
  expect(first.body.data.items).toHaveLength(2);
  expect(first.body.data.next_cursor).toBeTypeOf("string");
  const next = await request(app)
    .get("/api/v1/notifications")
    .query({ limit: 2, cursor: first.body.data.next_cursor })
    .set(h)
    .expect(200);
  const items = [...first.body.data.items, ...next.body.data.items];
  expect(items).toHaveLength(3);
  expect(new Set(items.map((x) => x.id)).size).toBe(3);
  expect(next.body.data.next_cursor).toBeNull();
  expect(JSON.stringify(items)).not.toContain("PRIVATE B");
});
it("read status is idempotent, ownership enforced and unread filter works", async () => {
  const item = await db.notifications.create({
    data: { owner_id: a, kind: "system", title: "Read once", body: "Test" },
  });
  const path = `/api/v1/notifications/${item.id}/read`;
  const one = await request(app).patch(path).set(h).expect(200);
  const two = await request(app).patch(path).set(h).expect(200);
  expect(two.body.data.read_at).toBe(one.body.data.read_at);
  const unread = await request(app)
    .get("/api/v1/notifications?unread=true")
    .set(h)
    .expect(200);
  expect(
    unread.body.data.items.every(
      (x: { read_at: unknown }) => x.read_at === null,
    ),
  ).toBe(true);
  const count = await request(app)
    .get("/api/v1/notifications/unread-count")
    .set(h)
    .expect(200);
  expect(count.body.data.unread_count).toBe(
    await db.notifications.count({ where: { owner_id: a, read_at: null } }),
  );
  auth(b);
  await request(app).patch(path).set(h).expect(404);
  await request(app)
    .patch(`/api/v1/notifications/${randomUUID()}/read`)
    .set(h)
    .expect(404);
});
it("rejects untrusted cursor/owner and requires authentication", async () => {
  for (const query of [
    "cursor=garbage",
    "limit=101",
    "limit=-1",
    "unread=anything",
    `owner_id=${b}`,
  ])
    await request(app)
      .get("/api/v1/notifications?" + query)
      .set(h)
      .expect(400);
  for (const path of [
    "/api/v1/notifications",
    "/api/v1/notifications/unread-count",
    `/api/v1/plants/${plant}/schedules`,
  ])
    await request(app).get(path).expect(401);
});

it("new user gets zero stats, empty inbox and no shared data", async () => {
  const fresh = randomUUID();
  auth(fresh, {});
  try {
    const me = await request(app).get("/api/v1/me").set(h).expect(200);
    expect(me.body.data).toMatchObject({
      total_plants: 0,
      total_ai_scans: 0,
      avatar_url: null,
    });
    const inbox = await request(app)
      .get("/api/v1/notifications")
      .set(h)
      .expect(200);
    expect(inbox.body.data).toEqual({ items: [], next_cursor: null });
    const unread = await request(app)
      .get("/api/v1/notifications/unread-count")
      .set(h)
      .expect(200);
    expect(unread.body.data.unread_count).toBe(0);
  } finally {
    await db.profiles.deleteMany({ where: { id: fresh } });
  }
});
it("notification SQL constraints reject empty content", async () => {
  await expect(
    db.notifications.create({
      data: { owner_id: a, kind: "water", title: "   ", body: "Text" },
    }),
  ).rejects.toThrow();
  await expect(
    db.notifications.create({
      data: { owner_id: a, kind: "unsupported", title: "Title", body: "Text" },
    }),
  ).rejects.toThrow();
});
