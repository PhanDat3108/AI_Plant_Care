import { expect, it, vi } from "vitest";
import { readConfig } from "../../src/config/env.js";
import { createCareProvider } from "../../src/services/gemini-care.js";
import {
  careDataSchema,
  reviewInputSchema,
} from "../../src/services/care-data-schema.js";

const config = readConfig({
  NODE_ENV: "test",
  DATABASE_URL: "postgresql://local/test",
  GEMINI_API_KEY: "test-secret",
});
const identity = {
  scientific_name: "Epipremnum aureum",
  common_name: "Trầu bà",
  sources: [],
};
const proposal = () => ({
  scientific_name: identity.scientific_name,
  care: {
    watering_days: null,
    fertilizing_days: null,
    water_guide:
      "Kiểm tra đất trước khi tưới; chưa đủ thông tin để gán chu kỳ.",
    light_guide: null,
    soil_guide: null,
    temperature_guide: null,
    fertilizer_guide: null,
  },
  assumptions: ["Đề xuất chưa đối chiếu nguồn."],
  source_ids: [] as string[],
});
const envelope = (data: unknown, finishReason = "STOP") =>
  Response.json({
    candidates: [
      { finishReason, content: { parts: [{ text: JSON.stringify(data) }] } },
    ],
  });
it("uses DB identity, JSON schema and server-only header; does not claim web searches", async () => {
  const fetcher = vi.fn<typeof fetch>().mockResolvedValue(envelope(proposal()));
  const result = await createCareProvider(config, fetcher).generate(identity);
  expect(result.care.watering_days).toBeNull();
  const [url, init] = fetcher.mock.calls[0];
  expect(String(url)).toMatch(
    /^https:\/\/generativelanguage.googleapis.com\/v1beta\/models\/.+:generateContent$/,
  );
  expect(String(url)).not.toContain("test-secret");
  expect(init?.headers).toMatchObject({ "x-goog-api-key": "test-secret" });
  const body = JSON.parse(String(init?.body));
  expect(body.generationConfig.responseMimeType).toBe("application/json");
  expect(body.generationConfig.thinkingConfig).toEqual({
    thinkingLevel: "LOW",
  });
  expect(body.generationConfig.responseJsonSchema.additionalProperties).toBe(
    false,
  );
  expect(JSON.parse(body.contents[0].parts[0].text)).toMatchObject(identity);
  expect(body.tools).toBeUndefined();
  expect(String(init?.body)).not.toContain("test-secret");
});
it("keeps unknown values null, checks interval bounds and requires matching guides", async () => {
  const p = proposal();
  for (const watering_days of [0, -1, 366, 1.5, "7"]) {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValue(
        envelope({ ...p, care: { ...p.care, watering_days } }),
      );
    await expect(
      createCareProvider(config, fetcher).generate(identity),
    ).rejects.toMatchObject({ code: "AI_INVALID_RESPONSE" });
  }
  expect(
    careDataSchema.safeParse({ ...p.care, water_guide: null, watering_days: 7 })
      .success,
  ).toBe(false);
  expect(
    careDataSchema.safeParse({ ...p.care, fertilizer_guide: "  " }).success,
  ).toBe(false);
});
it("rejects wrong species, invented references, missing keys, extra keys and truncated responses", async () => {
  const p = proposal();
  const { assumptions: _unused, ...missing } = p;
  void _unused;
  for (const value of [
    { ...p, scientific_name: "Aloe vera" },
    { ...p, source_ids: ["source_1"] },
    { ...p, care: { ...p.care, care_status: "verified" } },
    missing,
  ]) {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(envelope(value));
    await expect(
      createCareProvider(config, fetcher).generate(identity),
    ).rejects.toMatchObject({ code: "AI_INVALID_RESPONSE" });
  }
  for (const response of [
    envelope(p, "MAX_TOKENS"),
    Response.json({ promptFeedback: { blockReason: "SAFETY" } }),
  ])
    await expect(
      createCareProvider(config, vi.fn().mockResolvedValue(response)).generate(
        identity,
      ),
    ).rejects.toMatchObject({ code: "AI_INVALID_RESPONSE" });
});
it("passes curated excerpts as data with assigned source IDs", async () => {
  const p = { ...proposal(), source_ids: ["source_1"] };
  const fetcher = vi.fn<typeof fetch>().mockResolvedValue(envelope(p));
  const sources = [
    {
      title: "Fixture source",
      url: "https://example.org/care",
      excerpt: "Tưới khi lớp đất mặt khô.",
    },
  ];
  await createCareProvider(config, fetcher).generate({ ...identity, sources });
  const body = JSON.parse(String(fetcher.mock.calls[0][1]?.body));
  expect(JSON.parse(body.contents[0].parts[0].text).sources[0]).toMatchObject({
    id: "source_1",
    ...sources[0],
  });
});
it("maps provider failures without leaking credentials and never silently falls back to demo", async () => {
  for (const [status, code] of [
    [429, "AI_RATE_LIMITED"],
    [403, "AI_UNAVAILABLE"],
    [500, "AI_UNAVAILABLE"],
  ] as const) {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValue(new Response("test-secret", { status }));
    const provider = createCareProvider(config, fetcher);
    expect(provider.isMock).toBe(false);
    try {
      await provider.generate(identity);
      throw new Error("expected failure");
    } catch (error) {
      expect(error).toMatchObject({ code });
      expect(String(error)).not.toContain("test-secret");
    }
  }
  const offline = vi
    .fn<typeof fetch>()
    .mockRejectedValue(new Error("test-secret: network error"));
  await expect(
    createCareProvider(config, offline).generate(identity),
  ).rejects.toMatchObject({ code: "AI_UNAVAILABLE" });
  const huge = vi
    .fn<typeof fetch>()
    .mockResolvedValue(new Response("x".repeat(140000)));
  await expect(
    createCareProvider(config, huge).generate(identity),
  ).rejects.toMatchObject({ code: "AI_UNAVAILABLE" });
});
it("missing key yields explicitly labeled demo with no network request", async () => {
  const fetcher = vi.fn<typeof fetch>();
  const demo = createCareProvider({ ...config, GEMINI_API_KEY: "" }, fetcher);
  expect(demo).toMatchObject({ isMock: true, provider: "demo" });
  const p = await demo.generate(identity);
  expect(p.care.water_guide).toContain("DEMO");
  expect(fetcher).not.toHaveBeenCalled();
});
it("config requires a key in live mode, validates reviewer UUIDs and model path", () => {
  const env = { NODE_ENV: "test", DATABASE_URL: "postgresql://local/test" };
  expect(() => readConfig({ ...env, CARE_AI_MODE: "live" })).toThrow(
    "GEMINI_API_KEY",
  );
  expect(() =>
    readConfig({ ...env, CARE_REVIEWER_IDS: "not-a-uuid" }),
  ).toThrow();
  expect(() =>
    readConfig({ ...env, GEMINI_MODEL: "../../elsewhere" }),
  ).toThrow();
  expect(readConfig(env).CARE_REVIEWER_IDS).toEqual([]);
  expect(
    reviewInputSchema.safeParse({
      action: "approve",
      generation_id: "bad",
      note: "",
    }).success,
  ).toBe(false);
});
