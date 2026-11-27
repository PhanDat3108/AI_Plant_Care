import { afterEach, expect, it, vi } from "vitest";
import { fallbackWeatherProvider, openMeteoProvider, type Forecast } from "../../src/services/weather.js";
import { weatherApiProvider } from "../../src/services/weather-api.js";
import { weatherAdjustment } from "../../src/services/care-policy.js";
const now = new Date("2026-11-27T00:00:00Z");
const body = () => ({ location: { tz_id: "Asia/Ho_Chi_Minh" }, forecast: { forecastday: [{ date: "2026-11-28", day: {
  totalprecip_mm: 8, daily_chance_of_rain: "80", maxtemp_c: 28, totalsnow_cm: 0,
} }] } });
afterEach(() => vi.restoreAllMocks());
it("normalizes backup forecast and applies existing rain policy", async () => {
  const fetcher = vi.fn(async () => Response.json(body()));
  const p = weatherApiProvider("test-key", fetcher, () => now);
  const f = await p.forecast(21, 105, "Asia/Ho_Chi_Minh");
  expect(f).toMatchObject({ source: "weatherapi", days: [{ rain_mm: 8, rain_probability: 80, temperature_max_c: 28 }] });
  expect(weatherAdjustment({ forecast: f, original: new Date("2026-11-28T01:00:00Z"), now,
    intervalDays: 3, localTime: "08:00", timezone: "Asia/Ho_Chi_Minh", environment: "outdoor", kind: "water",
  })?.due_at.toISOString()).toBe("2026-11-29T01:00:00.000Z");
  await p.forecast(21, 105, "Asia/Ho_Chi_Minh");
  expect(fetcher).toHaveBeenCalledTimes(1);
});
it("primary success never consumes backup quota", async () => {
  const forecast = { source: "open-meteo" } as Forecast;
  const primary = { forecast: vi.fn(async () => forecast) };
  const backup = { forecast: vi.fn(async () => null) };
  expect(await fallbackWeatherProvider(primary, backup).forecast(1, 2, "UTC")).toBe(forecast);
  expect(backup.forecast).not.toHaveBeenCalled();
});
it("429 switches to backup and repeated clicks use both cooldown and cache", async () => {
  const primaryFetch = vi.fn(async () => new Response(null, { status: 429 }));
  const backupFetch = vi.fn(async () => Response.json(body()));
  const p = fallbackWeatherProvider(openMeteoProvider(primaryFetch, () => now), weatherApiProvider("key", backupFetch, () => now));
  const values = await Promise.all(Array.from({ length: 5 }, () => p.forecast(21, 105, "Asia/Ho_Chi_Minh")));
  expect(values.every(v => v?.source === "weatherapi")).toBe(true);
  expect(primaryFetch).toHaveBeenCalledTimes(1);
  expect(backupFetch).toHaveBeenCalledTimes(1);
});
it("missing key performs no external backup call", async () => {
  const fetcher = vi.fn();
  expect(await weatherApiProvider("", fetcher).forecast(21, 105, "UTC")).toBeNull();
  expect(fetcher).not.toHaveBeenCalled();
});
it("both providers failing preserves no-forecast behavior", async () => {
  const failed = { forecast: vi.fn(async () => { throw new Error("private-key-url"); }) };
  expect(await fallbackWeatherProvider(failed, failed).forecast(21, 105, "UTC")).toBeNull();
});
it("rejects timezone mismatch and malformed precipitation", async () => {
  const wrongZone = body(); wrongZone.location.tz_id = "America/New_York";
  const wrongRain = body(); wrongRain.forecast.forecastday[0].day.totalprecip_mm = -1;
  for (const data of [wrongZone, wrongRain]) {
    expect(await weatherApiProvider("key", async () => Response.json(data), () => now)
      .forecast(21, 105, "Asia/Ho_Chi_Minh")).toBeNull();
  }
});
it("accepts equivalent UTC offset timezone such as Asia/Bangkok for Asia/Ho_Chi_Minh", async () => {
  const sameOffset = body();
  sameOffset.location.tz_id = "Asia/Bangkok";
  const f = await weatherApiProvider("key", async () => Response.json(sameOffset), () => now)
    .forecast(21, 105, "Asia/Ho_Chi_Minh");
  expect(f?.source).toBe("weatherapi");
});
it("snow is not interpreted as rainfall", async () => {
  const data = body(); data.forecast.forecastday[0].day.totalsnow_cm = 1;
  const f = await weatherApiProvider("key", async () => Response.json(data), () => now).forecast(21, 105, "Asia/Ho_Chi_Minh");
  expect(f?.days[0].rain_mm).toBeNull();
});
it("backup rate limit pauses other locations and does not leak credentials to logs", async () => {
  let tick = now.getTime();
  const log = vi.spyOn(console, "warn").mockImplementation(() => {});
  const fetcher = vi.fn(async () => new Response(null, { status: 429, headers: { "Retry-After": "3600" } }));
  const p = weatherApiProvider("private-secret", fetcher, () => new Date(tick));
  await p.forecast(21, 105, "UTC");
  tick += 3599_000;
  await p.forecast(22, 106, "UTC");
  expect(fetcher).toHaveBeenCalledTimes(1);
  tick += 1000;
  await p.forecast(22, 106, "UTC");
  expect(fetcher).toHaveBeenCalledTimes(2);
  expect(JSON.stringify(log.mock.calls)).not.toContain("private-secret");
});
it("backup network errors return null without logging the request URL", async () => {
  const log = vi.spyOn(console, "warn").mockImplementation(() => {});
  const p = weatherApiProvider("private-secret", async () => { throw new Error("https://api.weatherapi.com/?key=private-secret"); });
  expect(await p.forecast(21, 105, "UTC")).toBeNull();
  expect(JSON.stringify(log.mock.calls)).not.toContain("private-secret");
});
