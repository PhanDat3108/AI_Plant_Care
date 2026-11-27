import { afterEach, expect, it, vi } from "vitest";
import { openMeteoProvider, sharedOpenMeteoProvider } from "../../src/services/weather.js";

afterEach(() => vi.restoreAllMocks());
const base = Date.parse("2026-11-27T00:00:00Z");
const ok = () => Response.json({
  daily_units: { rain_sum: "mm", precipitation_probability_max: "%", temperature_2m_max: "°C" },
  daily: { time: ["2026-11-27"], rain_sum: [0], precipitation_probability_max: [0], temperature_2m_max: [28] },
});
it("production callers share the same provider", () => {
  expect(sharedOpenMeteoProvider()).toBe(sharedOpenMeteoProvider());
});
it("429 pauses all locations for 15 minutes and concurrent same-location clicks coalesce", async () => {
  let now = base;
  const fetcher = vi.fn().mockResolvedValueOnce(new Response(null, { status: 429 })).mockImplementation(async () => ok());
  const p = openMeteoProvider(fetcher, () => new Date(now));
  await Promise.all(Array.from({ length: 10 }, () => p.forecast(10, 106, "UTC")));
  expect(fetcher).toHaveBeenCalledTimes(1);
  now += 14 * 60_000;
  expect(await p.forecast(11, 107, "UTC")).toBeNull();
  expect(fetcher).toHaveBeenCalledTimes(1);
  now += 60_000;
  expect(await p.forecast(11, 107, "UTC")).not.toBeNull();
  expect(fetcher).toHaveBeenCalledTimes(2);
  await p.forecast(11, 107, "UTC");
  expect(fetcher).toHaveBeenCalledTimes(2);
});
it.each(["3600", new Date(base + 3600_000).toUTCString()])("honors Retry-After %s", async (header) => {
  let now = base;
  const fetcher = vi.fn().mockResolvedValueOnce(new Response(null, { status: 429, headers: { "Retry-After": header } })).mockImplementation(async () => ok());
  const p = openMeteoProvider(fetcher, () => new Date(now));
  await p.forecast(10, 106, "UTC");
  now += 3599_000;
  await p.forecast(12, 108, "UTC");
  expect(fetcher).toHaveBeenCalledTimes(1);
  now += 1000;
  await p.forecast(12, 108, "UTC");
  expect(fetcher).toHaveBeenCalledTimes(2);
});
it("malformed Retry-After falls back and repeated 429 increases cooldown", async () => {
  let now = base;
  const fetcher = vi.fn().mockImplementation(async () => new Response(null, { status: 429, headers: { "Retry-After": "invalid" } }));
  const p = openMeteoProvider(fetcher, () => new Date(now));
  await p.forecast(10, 106, "UTC");
  now += 15 * 60_000;
  await p.forecast(10, 106, "UTC");
  now += 29 * 60_000;
  await p.forecast(10, 106, "UTC");
  expect(fetcher).toHaveBeenCalledTimes(2);
  now += 60_000;
  await p.forecast(10, 106, "UTC");
  expect(fetcher).toHaveBeenCalledTimes(3);
});
it("cached valid data stays available during global cooldown but expires normally", async () => {
  let now = base;
  const fetcher = vi.fn().mockResolvedValueOnce(ok()).mockResolvedValueOnce(new Response(null, { status: 429, headers: { "Retry-After": "7200" } }));
  const p = openMeteoProvider(fetcher, () => new Date(now));
  const cached = await p.forecast(10, 106, "UTC");
  await p.forecast(11, 107, "UTC");
  expect(await p.forecast(10, 106, "UTC")).toBe(cached);
  now += 3600_000;
  expect(await p.forecast(10, 106, "UTC")).toBeNull();
  expect(fetcher).toHaveBeenCalledTimes(2);
});
it("does not call different locations in parallel and permits retry after completion", async () => {
  let release!: (r: Response) => void;
  const fetcher = vi.fn().mockImplementationOnce(() => new Promise<Response>(resolve => { release = resolve; })).mockImplementation(async () => ok());
  const p = openMeteoProvider(fetcher, () => new Date(base));
  const first = p.forecast(10, 106, "UTC");
  expect(await p.forecast(11, 107, "UTC")).toBeNull();
  release(ok());
  await first;
  expect(await p.forecast(11, 107, "UTC")).not.toBeNull();
  expect(fetcher).toHaveBeenCalledTimes(2);
});
