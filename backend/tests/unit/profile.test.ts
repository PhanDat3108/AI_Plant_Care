import {
  afterAll,
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from "vitest";
import request from "supertest";
import { createApp } from "../../src/app.js";
import { readConfig } from "../../src/config/env.js";
import { createDatabase } from "../../src/config/database.js";

const config = readConfig({
  NODE_ENV: "test",
  DATABASE_URL: "postgresql://test@127.0.0.1:1/test",
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_PUBLISHABLE_KEY: "test-public-key",
});
const db = createDatabase(config.DATABASE_URL);
const app = createApp(config, db);
const id = "10000000-0000-4000-8000-000000000001";
const profile = {
  id,
  display_name: "Tên đã chỉnh",
  avatar_key: null,
  timezone: "Asia/Ho_Chi_Minh",
  created_at: new Date("2026-01-01T00:00:00Z"),
};

beforeEach(() => {
  vi.spyOn(db.plants, "count").mockResolvedValue(0);
  vi.spyOn(db.scans, "count").mockResolvedValue(0);
  vi.spyOn(db.care_logs, "groupBy").mockResolvedValue([]);
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});
afterAll(() => db.$disconnect());

function authorize(metadata: unknown = { full_name: "Tên từ Google" }) {
  const fetcher = vi
    .fn()
    .mockImplementation(async () =>
      Response.json({ id, user_metadata: metadata }),
    );
  vi.stubGlobal("fetch", fetcher);
  return fetcher;
}

describe("Profile authenticated API", () => {
  it("verifies the Supabase token and preserves a previously edited profile", async () => {
    const fetcher = authorize();
    const upsert = vi.spyOn(db.profiles, "upsert").mockResolvedValue(profile);
    for (let i = 0; i < 2; i++) {
      const response = await request(app)
        .get("/api/v1/me?user_id=someone-else")
        .set("Authorization", "Bearer valid-access-token")
        .expect(200);
      expect(response.body.data).toMatchObject({
        id,
        display_name: "Tên đã chỉnh",
        isDemo: false,
      });
    }
    expect(upsert).toHaveBeenCalledTimes(2);
    expect(upsert).toHaveBeenLastCalledWith({
      where: { id },
      create: { id, display_name: "Tên từ Google" },
      update: {},
    });
    expect(fetcher).toHaveBeenCalledWith(
      new URL("https://example.supabase.co/auth/v1/user"),
      expect.objectContaining({
        headers: {
          apikey: "test-public-key",
          Authorization: "Bearer valid-access-token",
        },
      }),
    );
  });

  it.each([
    [{ full_name: "   ", name: "  Google Name  " }, "Google Name"],
    [{ full_name: 123, name: "Provider Name" }, "Provider Name"],
    [null, "Người dùng"],
  ])("handles optional provider metadata %j", async (metadata, expected) => {
    authorize(metadata);
    const upsert = vi.spyOn(db.profiles, "upsert").mockResolvedValue(profile);
    await request(app)
      .get("/api/v1/me")
      .set("Authorization", "Bearer valid")
      .expect(200);
    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({ create: { id, display_name: expected } }),
    );
  });

  it("updates only the verified user's allowed profile fields", async () => {
    authorize();
    const upsert = vi.spyOn(db.profiles, "upsert").mockResolvedValue({
      ...profile,
      display_name: "Tên mới",
      timezone: "Asia/Tokyo",
    });
    const response = await request(app)
      .patch("/api/v1/me?user_id=someone-else")
      .set("Authorization", "Bearer valid")
      .send({ display_name: "  Tên mới  ", timezone: "Asia/Tokyo" })
      .expect(200);
    expect(response.body.data.display_name).toBe("Tên mới");
    expect(upsert).toHaveBeenCalledWith({
      where: { id },
      create: { id, display_name: "Tên mới", timezone: "Asia/Tokyo" },
      update: { display_name: "Tên mới", timezone: "Asia/Tokyo" },
    });
  });

  it.each([
    {},
    { id: "another-user", display_name: "Name" },
    { role: "admin" },
    { avatar_key: "another-user/photo" },
    { display_name: "  " },
    { display_name: "a".repeat(101) },
    { timezone: "Not/A_Zone" },
    { timezone: null },
  ])("rejects invalid profile fields %j before writing to DB", async (body) => {
    authorize();
    const upsert = vi.spyOn(db.profiles, "upsert");
    const response = await request(app)
      .patch("/api/v1/me")
      .set("Authorization", "Bearer valid")
      .send(body)
      .expect(400);
    expect(response.body.error.code).toBe("INVALID_INPUT");
    expect(upsert).not.toHaveBeenCalled();
  });

  it.each([401, 403])(
    "rejects expired or revoked tokens (provider %i)",
    async (status) => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue(new Response(null, { status })),
      );
      const upsert = vi.spyOn(db.profiles, "upsert");
      const response = await request(app)
        .patch("/api/v1/me")
        .set("Authorization", "Bearer expired-token")
        .send({ display_name: "Name" })
        .expect(401);
      expect(response.body.error.code).toBe("UNAUTHORIZED");
      expect(upsert).not.toHaveBeenCalled();
    },
  );

  it("does not contact Auth or DB when token is missing", async () => {
    const fetcher = authorize();
    const upsert = vi.spyOn(db.profiles, "upsert");
    await request(app)
      .patch("/api/v1/me")
      .send({ display_name: "Name" })
      .expect(401);
    expect(fetcher).not.toHaveBeenCalled();
    expect(upsert).not.toHaveBeenCalled();
  });

  it.each([
    new Response("provider-secret", { status: 500 }),
    Response.json({ id: "invalid-user-id" }),
  ])(
    "handles provider failures without exposing upstream data",
    async (upstream) => {
      vi.stubGlobal("fetch", vi.fn().mockResolvedValue(upstream));
      const upsert = vi.spyOn(db.profiles, "upsert");
      const response = await request(app)
        .get("/api/v1/me")
        .set("Authorization", "Bearer valid")
        .expect(503);
      expect(response.body.error.code).toBe("AUTH_UNAVAILABLE");
      expect(JSON.stringify(response.body)).not.toContain("provider-secret");
      expect(upsert).not.toHaveBeenCalled();
    },
  );
});
