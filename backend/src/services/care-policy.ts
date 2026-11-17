import { Temporal } from "@js-temporal/polyfill";
import type { Forecast } from "./weather.js";

export function localDate(date: Date, timezone: string) {
  return Temporal.Instant.fromEpochMilliseconds(date.getTime())
    .toZonedDateTimeISO(timezone)
    .toPlainDate();
}
export function atLocal(
  date: Temporal.PlainDate,
  time: string,
  timezone: string,
) {
  return new Date(
    date.toZonedDateTime({
      timeZone: timezone,
      plainTime: Temporal.PlainTime.from(time),
    }).epochMilliseconds,
  );
}
export function nextDue(
  anchor: Date,
  intervalDays: number,
  time: string,
  timezone: string,
) {
  return atLocal(
    localDate(anchor, timezone).add({ days: intervalDays }),
    time,
    timezone,
  );
}
export function dayBounds(date: string, timezone: string) {
  const d = Temporal.PlainDate.from(date);
  return {
    from: atLocal(d, "00:00", timezone),
    to: atLocal(d.add({ days: 1 }), "00:00", timezone),
  };
}
// Versioned MVP heuristics, not a measured soil-moisture or botanical diagnosis.
// Weather adjustments always use original_due_at, never accumulate day by day.
export function weatherAdjustment(input: {
  original: Date;
  now: Date;
  intervalDays: number;
  localTime: string;
  timezone: string;
  environment: string;
  kind: string;
  forecast: Forecast | null;
}) {
  const { original, now, timezone, forecast, localTime } = input;
  if (input.kind !== "water" || input.environment !== "outdoor") return null;
  if (
    !forecast ||
    forecast.timezone !== timezone ||
    now.getTime() - Date.parse(forecast.fetched_at) > 2 * 60 * 60_000 ||
    Date.parse(forecast.fetched_at) > now.getTime() + 60_000
  )
    return null;
  const date = localDate(original, timezone);
  if (Temporal.PlainDate.compare(date, localDate(now, timezone)) < 0)
    return null;
  const rain = forecast.days.find((d) => d.date === date.toString());
  if (
    rain &&
    rain.rain_mm !== null &&
    rain.rain_probability !== null &&
    rain.rain_mm >= 5 &&
    rain.rain_probability >= 60
  ) {
    return {
      due_at: atLocal(date.add({ days: 1 }), localTime, timezone),
      reason: "Dự báo mưa ≥5 mm, xác suất ≥60%: lùi nhắc kiểm tra tưới 1 ngày.",
      day: rain,
      policy: "rain-delay-1d",
    };
  }
  // A hot/dry day can bring the *inspection reminder* forward, not mandate watering.
  const earlyDate = date.subtract({ days: 1 });
  const hot = forecast.days.find((d) => d.date === earlyDate.toString());
  if (
    input.intervalDays >= 3 &&
    hot &&
    hot.temperature_max_c !== null &&
    hot.rain_mm !== null &&
    hot.temperature_max_c >= 35 &&
    hot.rain_mm < 1 &&
    Temporal.PlainDate.compare(earlyDate, localDate(now, timezone)) >= 0
  ) {
    return {
      due_at: atLocal(earlyDate, localTime, timezone),
      reason:
        "Dự báo nóng ≥35°C, ít mưa: nhắc kiểm tra độ ẩm sớm 1 ngày; chỉ tưới nếu cần.",
      day: hot,
      policy: "hot-dry-inspect-1d",
    };
  }
  if (rain && rain.rain_mm !== null && rain.rain_probability !== null)
    return { due_at: original, reason: null, day: rain, policy: "baseline" };
  return null;
}
