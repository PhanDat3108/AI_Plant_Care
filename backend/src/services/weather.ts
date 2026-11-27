import { z } from "zod";
import { weatherApiProvider } from "./weather-api.js";

export interface ForecastDay {
  date: string;
  rain_mm: number | null;
  rain_probability: number | null;
  temperature_max_c: number | null;
}
export interface Forecast {
  source: "open-meteo" | "weatherapi";
  fetched_at: string;
  timezone: string;
  days: ForecastDay[];
}
export interface WeatherProvider {
  forecast(
    latitude: number,
    longitude: number,
    timezone: string,
  ): Promise<Forecast | null>;
}
const responseSchema = z.object({
  daily_units: z.object({
    rain_sum: z.literal("mm"),
    precipitation_probability_max: z.literal("%"),
    temperature_2m_max: z.literal("°C"),
  }),
  daily: z.object({
    time: z.array(z.iso.date()).min(1).max(16),
    rain_sum: z.array(z.number().finite().min(0).nullable()),
    precipitation_probability_max: z.array(
      z.number().finite().min(0).max(100).nullable(),
    ),
    temperature_2m_max: z.array(
      z.number().finite().min(-100).max(80).nullable(),
    ),
  }),
});

let sharedProvider: WeatherProvider | undefined;
/** Share cache, in-flight calls and provider cooldown across all production callers. */
export function sharedWeatherProvider(): WeatherProvider {
  return sharedProvider ??= fallbackWeatherProvider(
    openMeteoProvider(),
    weatherApiProvider(process.env.WEATHERAPI_API_KEY?.trim() ?? ""),
  );
}

export function fallbackWeatherProvider(primary: WeatherProvider, backup: WeatherProvider): WeatherProvider {
  return {
    async forecast(latitude, longitude, timezone) {
      try {
        const result = await primary.forecast(latitude, longitude, timezone);
        if (result) return result;
      } catch {
        console.warn("WEATHER_PRIMARY_FAILED");
      }
      try {
        return await backup.forecast(latitude, longitude, timezone);
      } catch {
        console.warn("WEATHER_BACKUP_FAILED");
        return null;
      }
    },
  };
}

function retryDelay(header: string | null, now: number, fallback: number) {
  if (!header) return fallback;
  const seconds = /^\d+$/.test(header.trim()) ? Number(header) : NaN;
  const delay = Number.isFinite(seconds)
    ? seconds * 1000
    : Date.parse(header) - now;
  return Number.isFinite(delay) && delay > 0 ? Math.max(fallback, delay) : fallback;
}

// Fixed provider URL: caller cannot turn weather lookup into arbitrary HTTP access.
// Bound memory + cache + in-flight deduplication reduce provider quota usage.
export function openMeteoProvider(
  fetcher: typeof fetch = fetch,
  clock = () => new Date(),
): WeatherProvider {
  const cache = new Map<string, { until: number; value: Forecast | null }>();
  const pending = new Map<string, Promise<Forecast | null>>();
  let cooldownUntil = 0;
  let rateLimitCount = 0;
  return {
    async forecast(latitude, longitude, timezone) {
      if (
        !Number.isFinite(latitude) ||
        Math.abs(latitude) > 90 ||
        !Number.isFinite(longitude) ||
        Math.abs(longitude) > 180
      )
        return null;
      const key = `${latitude},${longitude},${timezone}`;
      const cached = cache.get(key);
      if (cached && cached.until > clock().getTime()) return cached.value;
      if (pending.has(key)) return pending.get(key)!;
      if (clock().getTime() < cooldownUntil) return null;
      // Avoid parallel requests for different locations on the same server IP.
      // Keep the current schedule; a later sync can fetch that location.
      if (pending.size > 0) return null;
      const request = (async () => {
        let value: Forecast | null = null;
        try {
          const url = new URL("https://api.open-meteo.com/v1/forecast");
          url.search = new URLSearchParams({
            latitude: String(latitude),
            longitude: String(longitude),
            timezone,
            forecast_days: "7",
            daily: "rain_sum,precipitation_probability_max,temperature_2m_max",
            temperature_unit: "celsius",
            precipitation_unit: "mm",
          }).toString();
          const r = await fetcher(url, { signal: AbortSignal.timeout(6000) });
          if (!r.ok) {
            console.warn("WEATHER_HTTP_ERROR", r.status);
            if (r.status === 429) {
              rateLimitCount = Math.min(rateLimitCount + 1, 7);
              const fallback = Math.min(15 * 60_000 * 2 ** (rateLimitCount - 1), 24 * 60 * 60_000);
              const delay = retryDelay(r.headers.get("retry-after"), clock().getTime(), fallback);
              cooldownUntil = Math.max(cooldownUntil, clock().getTime() + delay);
              console.warn("WEATHER_RATE_LIMITED", { retry_at: new Date(cooldownUntil).toISOString() });
              return null;
            }
            throw new Error("weather unavailable");

          }
          const { daily } = responseSchema.parse(await r.json());
          if (
            [
              daily.rain_sum,
              daily.precipitation_probability_max,
              daily.temperature_2m_max,
            ].some((a) => a.length !== daily.time.length)
          )
            throw new Error("weather malformed");
          rateLimitCount = 0;
          value = {
            source: "open-meteo",
            fetched_at: clock().toISOString(),
            timezone,
            days: daily.time.map((date, i) => ({
              date,
              rain_mm: daily.rain_sum[i],
              rain_probability: daily.precipitation_probability_max[i],
              temperature_max_c: daily.temperature_2m_max[i],
            })),
          };
        } catch (error) {
          // Only log the error class, never coordinates or provider response bodies.
          console.warn("WEATHER_LOOKUP_FAILED", error instanceof Error ? error.name : "UnknownError");
          /* Keep the previously scheduled task unchanged on timeout/errors. */
        }
        if (cache.size >= 500) cache.delete(cache.keys().next().value!);
        cache.set(key, {
          until: clock().getTime() + (value ? 60 * 60_000 : 60_000),
          value,
        });
        return value;
      })();
      pending.set(key, request);
      try {
        return await request;
      } finally {
        pending.delete(key);
      }
    },
  };
}
