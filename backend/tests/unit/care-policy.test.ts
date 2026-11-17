import { expect, it, vi } from "vitest";
import {
  dayBounds,
  nextDue,
  weatherAdjustment,
} from "../../src/services/care-policy.js";
import {
  openMeteoProvider,
  type Forecast,
} from "../../src/services/weather.js";
const now = new Date("2026-11-16T00:00:00Z");
const forecast: Forecast = {
  source: "open-meteo",
  fetched_at: now.toISOString(),
  timezone: "Asia/Ho_Chi_Minh",
  days: [
    {
      date: "2026-11-16",
      rain_mm: 0,
      rain_probability: 0,
      temperature_max_c: 36,
    },
    {
      date: "2026-11-17",
      rain_mm: 8,
      rain_probability: 80,
      temperature_max_c: 28,
    },
  ],
};
const input = {
  now,
  original: new Date("2026-11-17T01:00:00Z"),
  intervalDays: 7,
  localTime: "08:00",
  timezone: "Asia/Ho_Chi_Minh",
  environment: "outdoor",
  kind: "water",
  forecast,
};
it("baseline uses each species interval and local hour", () => {
  expect(nextDue(now, 3, "08:00", "Asia/Ho_Chi_Minh").toISOString()).toBe(
    "2026-11-19T01:00:00.000Z",
  );
  expect(nextDue(now, 7, "08:00", "Asia/Ho_Chi_Minh").toISOString()).toBe(
    "2026-11-23T01:00:00.000Z",
  );
});
it("calendar days handle DST without fixed 24-hour arithmetic", () => {
  expect(
    nextDue(
      new Date("2026-03-07T13:00:00Z"),
      1,
      "08:00",
      "America/New_York",
    ).toISOString(),
  ).toBe("2026-03-08T12:00:00.000Z");
  const bounds = dayBounds("2026-03-08", "America/New_York");
  expect(bounds.to.getTime() - bounds.from.getTime()).toBe(23 * 3600000);
});
it("rain postpones by one day from original date on every run", () => {
  const one = weatherAdjustment(input);
  const two = weatherAdjustment({
    ...input,
    now: new Date("2026-11-16T00:30:00Z"),
  });
  expect(one?.due_at.toISOString()).toBe("2026-11-18T01:00:00.000Z");
  expect(two?.due_at).toEqual(one?.due_at);
  expect(one?.policy).toBe("rain-delay-1d");
});
it("hot dry forecast advances inspection but not a daily-watering rule", () => {
  const dry = {
    ...forecast,
    days: [
      forecast.days[0],
      { ...forecast.days[1], rain_mm: 0, rain_probability: 0 },
    ],
  };
  expect(
    weatherAdjustment({ ...input, forecast: dry })?.due_at.toISOString(),
  ).toBe("2026-11-16T01:00:00.000Z");
  expect(
    weatherAdjustment({ ...input, intervalDays: 1, forecast: dry })?.policy,
  ).toBe("baseline");
});
it("indoors, fertilizer, unknown location forecasts and stale data do not adjust", () => {
  for (const update of [
    { environment: "indoor" },
    { environment: "unknown" },
    { kind: "fertilize" },
    { forecast: null },
    { forecast: { ...forecast, fetched_at: "2026-11-10T00:00:00Z" } },
    { forecast: { ...forecast, timezone: "UTC" } },
    { now: new Date("2026-11-19T00:00:00Z") },
  ])
    expect(weatherAdjustment({ ...input, ...update })).toBeNull();
});
const response = () =>
  Response.json({
    daily_units: {
      rain_sum: "mm",
      precipitation_probability_max: "%",
      temperature_2m_max: "°C",
    },
    daily: {
      time: ["2026-11-16"],
      rain_sum: [8],
      precipitation_probability_max: [80],
      temperature_2m_max: [30],
    },
  });
it("weather provider coalesces requests and caches without mixing locations", async () => {
  const fetcher = vi.fn().mockImplementation(async () => response());
  const provider = openMeteoProvider(fetcher, () => now);
  const [a, b] = await Promise.all([
    provider.forecast(10, 106, "Asia/Ho_Chi_Minh"),
    provider.forecast(10, 106, "Asia/Ho_Chi_Minh"),
  ]);
  expect(a).toEqual(b);
  expect(a?.days[0].rain_mm).toBe(8);
  expect(fetcher).toHaveBeenCalledTimes(1);
  await provider.forecast(10, 106, "Asia/Ho_Chi_Minh");
  expect(fetcher).toHaveBeenCalledTimes(1);
  await provider.forecast(11, 106, "Asia/Ho_Chi_Minh");
  expect(fetcher).toHaveBeenCalledTimes(2);
  expect(new URL(String(fetcher.mock.calls[0][0])).hostname).toBe(
    "api.open-meteo.com",
  );
});
it("weather failures, wrong units and missing data return no forecast", async () => {
  for (const fetcher of [
    vi.fn().mockRejectedValue(new Error("timeout")),
    vi.fn().mockResolvedValue(new Response(null, { status: 429 })),
    vi.fn().mockResolvedValue(Response.json({ daily: {} })),
  ])
    expect(
      await openMeteoProvider(fetcher, () => now).forecast(10, 106, "UTC"),
    ).toBeNull();
});
