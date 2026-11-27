import "dotenv/config";
import { randomUUID } from "node:crypto";
import { afterAll, afterEach, beforeAll, expect, it, vi } from "vitest";
import request from "supertest";
import { createDatabase } from "../../src/config/database.js";
import { readConfig } from "../../src/config/env.js";
import { createApp } from "../../src/app.js";

const db = createDatabase(process.env.DATABASE_URL!);
const a = randomUUID(),
  b = randomUUID(),
  plantId = randomUUID(),
  speciesId = randomUUID();
const secondSpeciesId = randomUUID(),
  imageId = randomUUID();
const app = createApp(
  readConfig({
    NODE_ENV: "test",
    DATABASE_URL: process.env.DATABASE_URL,
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_PUBLISHABLE_KEY: "test-public-key",
  }),
  db,
);

beforeAll(async () => {
  await db.profiles.createMany({
    data: [
      { id: a, display_name: "Test A" },
      { id: b, display_name: "Test B" },
    ],
  });
  await db.plant_species.createMany({
    data: [
      { id: speciesId, scientific_name: "Test species " + speciesId },
      {
        id: secondSpeciesId,
        scientific_name: "Test species " + secondSpeciesId,
      },
    ],
  });
  await db.plants.create({
    data: {
      id: plantId,
      owner_id: a,
      species_id: speciesId,
      nickname: "Cây thử",
    },
  });
  await db.reference_images.create({
    data: {
      id: imageId,
      species_id: speciesId,
      provider: "fixture",
      provider_image_id: imageId,
      image_url: "https://example.com/leaf.jpg",
      source_url: "https://example.com/source",
      attribution: "Test fixture",
      license_name: "Fixture only",
    },
  });
});
afterEach(() => vi.unstubAllGlobals());
afterAll(async () => {
  await db.profiles.deleteMany({ where: { id: { in: [a, b] } } });
  await db.reference_images.deleteMany({ where: { id: imageId } });
  await db.plant_species.deleteMany({
    where: { id: { in: [speciesId, secondSpeciesId] } },
  });
  await db.$disconnect();
});
function authorize(id: string) {
  vi.stubGlobal(
    "fetch",
    vi.fn().mockImplementation(async () => Response.json({ id })),
  );
}
function scan(requestId: string, ownerId = a) {
  return db.scans.create({
    data: {
      owner_id: ownerId,
      plant_id: plantId,
      request_id: requestId,
      image_key: "test/leaf.jpg",
      mode: "both",
      source: "test",
      is_mock: true,
      health_status: "unknown",
    },
  });
}
it("ready thực sự truy cập được DB", async () => {
  await request(app).get("/api/v1/ready").expect(200);
});
it("chủ cây thấy đúng dữ liệu và metadata ảnh tham khảo", async () => {
  authorize(a);
  await db.plants.update({
    where: { id: plantId },
    data: { reference_image_id: imageId },
  });
  const r = await request(app)
    .get("/api/v1/garden/" + plantId)
    .set("Authorization", "Bearer test")
    .expect(200);
  expect(r.body.data.referenceImage.attribution).toBe("Test fixture");
  expect(r.body.data.owner_id).toBe(a);
});
it("người khác không xem được cây kể cả biết UUID", async () => {
  authorize(b);
  await request(app)
    .get("/api/v1/garden/" + plantId)
    .set("Authorization", "Bearer test")
    .expect(404);
  const r = await request(app)
    .get("/api/v1/garden")
    .set("Authorization", "Bearer test")
    .expect(200);
  expect(r.body.data).toEqual([]);
});
it("DB chặn gắn ảnh bìa sai loài hoặc đồng thời dùng hai nguồn", async () => {
  await expect(
    db.plants.update({
      where: { id: plantId },
      data: { species_id: secondSpeciesId },
    }),
  ).rejects.toThrow();
  await expect(
    db.plants.update({
      where: { id: plantId },
      data: { cover_image_key: "a.jpg" },
    }),
  ).rejects.toThrow();
});
it("quét lại tạo lịch sử, gửi đồng thời cùng request chỉ lưu một lần", async () => {
  const key = randomUUID();
  const results = await Promise.allSettled([scan(key), scan(key)]);
  expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
  await scan(randomUUID());
  expect(await db.scans.count({ where: { plant_id: plantId } })).toBe(2);
});
it("DB chặn lần quét của owner khác và xác suất sai", async () => {
  await expect(scan(randomUUID(), b)).rejects.toThrow();
  const saved = await db.scans.findFirstOrThrow({
    where: { plant_id: plantId },
  });
  await expect(
    db.scans.update({
      where: { id: saved.id },
      data: { species_confidence: 1.1 },
    }),
  ).rejects.toThrow();
});
it("transaction lỗi rollback toàn bộ cây mới", async () => {
  const id = randomUUID();
  await expect(
    db.$transaction(async (tx) => {
      await tx.plants.create({
        data: { id, owner_id: a, nickname: "Rollback" },
      });
      await tx.care_schedules.create({
        data: {
          plant_id: id,
          kind: "water",
          interval_days: 0,
          local_time: new Date("1970-01-01T08:00:00Z"),
        },
      });
    }),
  ).rejects.toThrow();
  expect(await db.plants.findUnique({ where: { id } })).toBeNull();
});
it("lịch và log kiểm tra loại việc, chống ghi hoàn thành trùng", async () => {
  const schedule = await db.care_schedules.create({
    data: {
      plant_id: plantId,
      kind: "water",
      interval_days: 7,
      local_time: new Date("1970-01-01T08:00:00Z"),
    },
  });
  const date = new Date();
  const task = await db.care_tasks.create({
    data: {
      schedule_id: schedule.id,
      plant_id: plantId,
      kind: "water",
      due_at: date,
      original_due_at: date,
    },
  });
  await expect(
    db.care_logs.create({
      data: {
        plant_id: plantId,
        request_id: randomUUID(),
        task_id: task.id,
        kind: "fertilize",
      },
    }),
  ).rejects.toThrow();
  await db.care_logs.create({
    data: {
      plant_id: plantId,
      request_id: randomUUID(),
      task_id: task.id,
      kind: "water",
    },
  });
  await expect(
    db.care_logs.create({
      data: {
        plant_id: plantId,
        request_id: randomUUID(),
        task_id: task.id,
        kind: "water",
      },
    }),
  ).rejects.toThrow();
  await db.care_tasks.update({
    where: { id: task.id },
    data: {
      due_at: new Date(date.getTime() + 86400000),
      adjustment_reason: "Mưa demo",
      weather_snapshot: { is_mock: true, precipitation_mm: 20 },
    },
  });
  expect(
    (await db.care_tasks.findUniqueOrThrow({ where: { id: task.id } }))
      .original_due_at,
  ).toEqual(date);
});
