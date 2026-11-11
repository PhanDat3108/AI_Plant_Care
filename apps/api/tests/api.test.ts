import { afterEach, describe, expect, it, vi } from "vitest";
import request from "supertest";
import { createApp } from "../src/app.js";
import { readConfig } from "../src/config/env.js";
const development = readConfig({
  NODE_ENV: "development",
  DEV_AUTH_BYPASS: "true",
});
const app = createApp(development);
const protectedApp = createApp(
  readConfig({
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_PUBLISHABLE_KEY: "test",
  }),
);
afterEach(() => vi.unstubAllGlobals());
describe("HTTP API", () => {
  it.each(["production", "staging", "test"])(
    "rejects bypass in %s",
    (NODE_ENV) => {
      expect(() => readConfig({ NODE_ENV, DEV_AUTH_BYPASS: "true" })).toThrow();
    },
  );
  it("health is public", async () => {
    expect(
      (await request(protectedApp).get("/api/v1/health")).body.data.status,
    ).toBe("ok");
  });
  it("requires bearer auth", async () => {
    await request(protectedApp).get("/api/v1/plants").expect(401);
  });
  it("rejects tokens refused by Supabase", async () => {
    const fetcher = vi
      .fn()
      .mockResolvedValue(new Response(null, { status: 401 }));
    vi.stubGlobal("fetch", fetcher);
    await request(protectedApp)
      .get("/api/v1/plants")
      .set("Authorization", "Bearer invalid")
      .expect(401);
    expect(fetcher).toHaveBeenCalledOnce();
  });
  it("analyzes mock PNG without calling a provider", async () => {
    const fetcher = vi.fn();
    vi.stubGlobal("fetch", fetcher);
    const image = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=",
      "base64",
    );
    const r = await request(app)
      .post("/api/v1/scans/analyze")
      .attach("image", image, "leaf.png")
      .expect(200);
    expect(r.body.data).toMatchObject({
      isMock: true,
      species: { name: "Epipremnum aureum" },
    });
    expect(fetcher).not.toHaveBeenCalled();
  });
  it("rejects missing, mislabeled and oversized uploads", async () => {
    const url = "/api/v1/scans/analyze";
    await request(app).post(url).expect(400);
    await request(app)
      .post(url)
      .attach("image", Buffer.from("text"), "fake.png")
      .expect(415);
    await request(app)
      .post(url)
      .attach("image", Buffer.alloc(5 * 1024 * 1024 + 1), "big.png")
      .expect(413);
  });
  it("validates coordinates and flags mock forecasts", async () => {
    await request(app)
      .get("/api/v1/weather/forecast?latitude=91&longitude=0")
      .expect(400);
    expect(
      (
        await request(app).get(
          "/api/v1/weather/forecast?latitude=10&longitude=106",
        )
      ).body.data.isMock,
    ).toBe(true);
  });
  it("rejects supplied owner IDs", async () => {
    await request(app)
      .post("/api/v1/plants")
      .send({ name: "Lan", ownerId: "mine" })
      .expect(400);
  });
});
