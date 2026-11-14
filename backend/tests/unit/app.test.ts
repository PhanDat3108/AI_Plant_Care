import { afterAll, afterEach, describe, expect, it, vi } from "vitest";
import request from "supertest";
import { readConfig } from "../../src/config/env.js";
import { createDatabase } from "../../src/config/database.js";
import { createApp } from "../../src/app.js";

const config = readConfig({
  NODE_ENV: "test",
  DATABASE_URL: "postgresql://test@127.0.0.1:1/test",
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_PUBLISHABLE_KEY: "test-public-key",
});
const db = createDatabase(config.DATABASE_URL);
const app = createApp(config, db);
afterEach(() => vi.restoreAllMocks());
afterEach(() => vi.unstubAllGlobals());
afterAll(() => db.$disconnect());

describe("HTTP nền tảng", () => {
  it("health công khai và không gọi DB", async () => {
    const r = await request(app).get("/api/v1/health").expect(200);
    expect(r.body.data).toEqual({ status: "ok", demoAuth: false });
    expect(r.headers["x-request-id"]).toBeTruthy();
  });
  it("readiness trả 503 khi DB không sẵn sàng", async () => {
    vi.spyOn(db.profiles, "count").mockRejectedValue(
      new Error("secret connection string"),
    );
    const r = await request(app).get("/api/v1/ready").expect(503);
    expect(r.body.error.code).toBe("DATABASE_UNAVAILABLE");
    expect(JSON.stringify(r.body)).not.toContain("secret");
  });
  it("thiếu token bị từ chối", async () => {
    await request(app).get("/api/v1/plants").expect(401);
  });
  it("token giả bị dịch vụ Auth từ chối", async () => {
    const fetcher = vi
      .fn()
      .mockResolvedValue(new Response(null, { status: 401 }));
    vi.stubGlobal("fetch", fetcher);
    await request(app)
      .get("/api/v1/me")
      .set("Authorization", "Bearer forged")
      .expect(401);
    expect(fetcher).toHaveBeenCalledOnce();
  });
  it("Auth lỗi mạng trả 503", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("network")));
    await request(app)
      .get("/api/v1/me")
      .set("Authorization", "Bearer token")
      .expect(503);
  });
  it("chỉ lấy owner từ kết quả xác minh", async () => {
    const userId = "10000000-0000-4000-8000-000000000001";
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(Response.json({ id: userId })),
    );
    const query = vi.spyOn(db.plants, "findMany").mockResolvedValue([]);
    await request(app)
      .get("/api/v1/plants?owner_id=someone-else")
      .set("Authorization", "Bearer valid")
      .expect(200);
    expect(query).toHaveBeenCalledWith(
      expect.objectContaining({ where: { owner_id: userId } }),
    );
  });
  it("UUID và phân trang được kiểm tra", async () => {
    const demo = createApp(
      readConfig({
        NODE_ENV: "development",
        DATABASE_URL: config.DATABASE_URL,
        DEV_AUTH_BYPASS: "true",
      }),
      db,
    );
    await request(demo).get("/api/v1/plants/not-a-uuid").expect(400);
    await request(demo).get("/api/v1/plants?limit=1000").expect(400);
  });
});
describe("Environment", () => {
  it.each(["production", "staging", "test"])("chặn bypass ở %s", (NODE_ENV) => {
    expect(() =>
      readConfig({
        NODE_ENV,
        DATABASE_URL: config.DATABASE_URL,
        DEV_AUTH_BYPASS: "true",
      }),
    ).toThrow();
  });
  it("mặc định tắt bypass", () => expect(config.DEV_AUTH_BYPASS).toBe(false));
});
