import { Temporal } from "@js-temporal/polyfill";
import { z } from "zod";
import type { Forecast, WeatherProvider } from "./weather.js";

const number = z.number().finite();
const schema = z.object({
  location: z.object({ tz_id: z.string() }),
  forecast: z.object({ forecastday: z.array(z.object({
    date: z.iso.date(),
    day: z.object({
      totalprecip_mm: number.min(0).nullable(),
      daily_chance_of_rain: z.union([number, z.string().regex(/^\d+(\.\d+)?$/).transform(Number)])
        .pipe(z.number().min(0).max(100)).nullable(),
      maxtemp_c: number.min(-100).max(80).nullable(),
      totalsnow_cm: number.min(0).nullable().optional(),
    }),
  })).min(1).max(3) }),
});

function canonicalZone(zone: string) {
  return new Intl.DateTimeFormat("en", { timeZone: zone }).resolvedOptions().timeZone;
}

function sameLocalClock(providerZone: string, userZone: string, at: Date) {
  if (canonicalZone(providerZone) === canonicalZone(userZone)) return true;
  const instant = Temporal.Instant.fromEpochMilliseconds(at.getTime());
  return (
    instant.toZonedDateTimeISO(providerZone).offsetNanoseconds ===
    instant.toZonedDateTimeISO(userZone).offsetNanoseconds
  );
}

// Bound response memory; never log the URL (it includes the API key), body or errors.
async function readJson(response: Response) {
  const reader = response.body?.getReader();
  if (!reader) throw new Error("empty response");
  let size = 0;
  let text = "";
  const decoder = new TextDecoder();
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 512_000) { await reader.cancel(); throw new Error("oversized response"); }
      text += decoder.decode(value, { stream: true });
    }
    return JSON.parse(text + decoder.decode()) as unknown;
  } finally { reader.releaseLock(); }
}

/** Optional 3-day fallback. No invented days or relabeling of local dates. */
export function weatherApiProvider(
  apiKey: string,
  fetcher: typeof fetch = fetch,
  clock = () => new Date(),
): WeatherProvider {
  const cache = new Map<string, { until: number; value: Forecast | null }>();
  const pending = new Map<string, Promise<Forecast | null>>();
  let blockedUntil = 0;
  return {
    async forecast(latitude, longitude, timezone) {
      if (!apiKey || !Number.isFinite(latitude) || Math.abs(latitude) > 90 ||
          !Number.isFinite(longitude) || Math.abs(longitude) > 180) return null;
      const key = `${latitude},${longitude},${timezone}`;
      const cached = cache.get(key);
      if (cached && cached.until > clock().getTime()) return cached.value;
      if (pending.has(key)) return pending.get(key)!;
      if (clock().getTime() < blockedUntil || pending.size > 0) return null;
      const request = (async () => {
        let value: Forecast | null = null;
        try {
          canonicalZone(timezone);
          const url = new URL("https://api.weatherapi.com/v1/forecast.json");
          url.search = new URLSearchParams({ key: apiKey, q: `${latitude},${longitude}`, days: "3", aqi: "no", alerts: "no" }).toString();
          const r = await fetcher(url, { signal: AbortSignal.timeout(6000) });
          if (!r.ok) {
            console.warn("WEATHER_BACKUP_HTTP_ERROR", r.status);
            if ([401, 403, 429].includes(r.status)) {
              const raw = r.headers.get("retry-after") ?? "";
              const delay = /^\d+$/.test(raw) ? Number(raw) * 1000 : Date.parse(raw) - clock().getTime();
              blockedUntil = clock().getTime() + Math.max(15 * 60_000, Number.isFinite(delay) ? delay : 0);
            }
            throw new Error("provider unavailable");
          }
          const data = schema.parse(await readJson(r));
          if (!sameLocalClock(data.location.tz_id, timezone, clock())) {
            throw new Error(`timezone mismatch (${data.location.tz_id} vs ${timezone})`);
          }
          const days = data.forecast.forecastday;
          if (new Set(days.map(d => d.date)).size !== days.length) throw new Error("duplicate dates");
          value = {
            source: "weatherapi", fetched_at: clock().toISOString(), timezone,
            days: days.map(({ date, day }) => ({
              date,
              // Total precipitation includes snow: do not treat it as rainfall.
              rain_mm: (day.totalsnow_cm ?? 0) > 0 ? null : day.totalprecip_mm,
              rain_probability: day.daily_chance_of_rain,
              temperature_max_c: day.maxtemp_c,
            })),
          };
          console.info("WEATHER_FALLBACK_USED", "weatherapi");
        } catch (error) {
          const reason =
            error instanceof z.ZodError
              ? `schema:${error.issues.map((i) => i.path.join(".")).join(",")}`
              : error instanceof Error &&
                  (error.message.startsWith("timezone mismatch") ||
                    ["provider unavailable", "duplicate dates", "empty response", "oversized response"].includes(
                      error.message,
                    ))
                ? error.message
                : error instanceof Error
                  ? error.name
                  : "unknown";
          console.warn("WEATHER_BACKUP_UNAVAILABLE", reason);
        }
        if (cache.size >= 500) cache.delete(cache.keys().next().value!);
        cache.set(key, { until: clock().getTime() + (value ? 3600_000 : 60_000), value });
        return value;
      })();
      pending.set(key, request);
      try { return await request; } finally { pending.delete(key); }
    },
  };
}
