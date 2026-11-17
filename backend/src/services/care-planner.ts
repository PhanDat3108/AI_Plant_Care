import { Prisma } from "../generated/prisma/client.js";
import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";
import { nextDue, weatherAdjustment } from "./care-policy.js";
import type { WeatherProvider } from "./weather.js";

export function carePlanner(
  db: Database,
  weather: WeatherProvider,
  clock = () => new Date(),
) {
  return {
    async sync(ownerId: string, plantId: string) {
      // Network work outside transaction; re-check owner and context after locking.
      const context = await db.plants.findFirst({
        where: { id: plantId, owner_id: ownerId },
        include: { profiles: true },
      });
      if (!context)
        throw new HttpError(404, "NOT_FOUND", "Không tìm thấy cây của bạn.");
      const now = clock();
      const hasLocation =
        context.latitude !== null && context.longitude !== null;
      const forecast =
        context.environment === "outdoor" && hasLocation
          ? await weather.forecast(
              Number(context.latitude),
              Number(context.longitude),
              context.profiles.timezone,
            )
          : null;
      return db.$transaction(
        async (tx) => {
          const locked = await tx.$queryRaw<
            { id: string }[]
          >`SELECT id FROM plantcare.plants WHERE id=${plantId}::uuid AND owner_id=${ownerId}::uuid FOR UPDATE`;
          if (!locked.length)
            throw new HttpError(
              404,
              "NOT_FOUND",
              "Không tìm thấy cây của bạn.",
            );
          const plant = await tx.plants.findUniqueOrThrow({
            where: { id: plantId },
            include: { profiles: true, plant_species: true },
          });
          const warnings: string[] = [];
          const sameContext =
            plant.environment === context.environment &&
            String(plant.latitude) === String(context.latitude) &&
            String(plant.longitude) === String(context.longitude) &&
            plant.profiles.timezone === context.profiles.timezone;
          const usableForecast = sameContext ? forecast : null;
          if (plant.environment === "unknown")
            warnings.push("ENVIRONMENT_UNKNOWN_BASELINE_ONLY");
          if (plant.environment === "outdoor" && !hasLocation)
            warnings.push("LOCATION_REQUIRED_FOR_WEATHER");
          if (plant.environment === "outdoor" && hasLocation && !usableForecast)
            warnings.push("WEATHER_UNAVAILABLE_KEEP_EXISTING_DUE");
          for (const [kind, days] of [
            ["water", plant.plant_species?.watering_days],
            ["fertilize", plant.plant_species?.fertilizing_days],
          ] as const) {
            const existing = await tx.care_schedules.findUnique({
              where: { plant_id_kind: { plant_id: plantId, kind } },
            });
            if (!existing) {
              if (
                plant.plant_species &&
                plant.plant_species.care_status !== "verified"
              ) {
                if (!warnings.includes("CARE_DATA_REVIEW_REQUIRED"))
                  warnings.push("CARE_DATA_REVIEW_REQUIRED");
                continue;
              }
              if (!days || days < 1 || days > 365) {
                warnings.push(`MISSING_${kind.toUpperCase()}_INTERVAL`);
                continue;
              }
              await tx.care_schedules.create({
                data: {
                  plant_id: plantId,
                  kind,
                  interval_days: days,
                  local_time: new Date("1970-01-01T08:00:00Z"),
                  starts_at: now,
                },
              });
            }
          }
          const schedules = await tx.care_schedules.findMany({
            where: { plant_id: plantId, enabled: true },
            orderBy: { kind: "asc" },
          });
          const tasks = [];
          let addedNotifications = 0;
          for (const schedule of schedules) {
            const time = schedule.local_time.toISOString().slice(11, 16);
            const lastLog = await tx.care_logs.findFirst({
              where: { plant_id: plantId, kind: schedule.kind },
              orderBy: [{ performed_at: "desc" }, { id: "desc" }],
            });
            const anchor =
              lastLog && lastLog.performed_at > schedule.starts_at
                ? lastLog.performed_at
                : schedule.starts_at;
            const expectedDue = nextDue(
              anchor,
              schedule.interval_days,
              time,
              plant.profiles.timezone,
            );
            // Rule/timezone/log changes supersede the old pending occurrence.
            await tx.care_tasks.updateMany({
              where: {
                schedule_id: schedule.id,
                state: "pending",
                original_due_at: { not: expectedDue },
              },
              data: { state: "skipped" },
            });
            let task = await tx.care_tasks.findFirst({
              where: { schedule_id: schedule.id, state: "pending" },
              orderBy: { original_due_at: "asc" },
            });
            if (!task) {
              const due = expectedDue;
              const previous = await tx.care_tasks.findUnique({
                where: {
                  schedule_id_original_due_at: {
                    schedule_id: schedule.id,
                    original_due_at: due,
                  },
                },
              });
              // Completed/skipped without a matching care log is an integration inconsistency.
              if (previous?.state === "done") {
                warnings.push(
                  `CARE_LOG_REQUIRED_${schedule.kind.toUpperCase()}`,
                );
                continue;
              }
              task = previous
                ? await tx.care_tasks.update({
                    where: { id: previous.id },
                    data: {
                      state: "pending",
                      due_at: due,
                      adjustment_reason: null,
                      weather_snapshot: Prisma.DbNull,
                    },
                  })
                : await tx.care_tasks.create({
                    data: {
                      schedule_id: schedule.id,
                      plant_id: plantId,
                      kind: schedule.kind,
                      original_due_at: due,
                      due_at: due,
                    },
                  });
            }
            const eventKey = `care-task:${task.id}`;
            const notified = await tx.notifications.findUnique({
              where: {
                owner_id_event_key: { owner_id: ownerId, event_key: eventKey },
              },
              select: { id: true },
            });
            if (!notified) {
              if (plant.environment !== "outdoor" && task.adjustment_reason) {
                task = await tx.care_tasks.update({
                  where: { id: task.id },
                  data: {
                    due_at: task.original_due_at,
                    adjustment_reason: null,
                    weather_snapshot: Prisma.DbNull,
                  },
                });
              }
              const adjustment = weatherAdjustment({
                original: task.original_due_at,
                now,
                intervalDays: schedule.interval_days,
                localTime: time,
                timezone: plant.profiles.timezone,
                environment: plant.environment,
                kind: schedule.kind,
                forecast: usableForecast,
              });
              if (adjustment && usableForecast)
                task = await tx.care_tasks.update({
                  where: { id: task.id },
                  data: {
                    due_at: adjustment.due_at,
                    adjustment_reason: adjustment.reason,
                    weather_snapshot: {
                      source: usableForecast.source,
                      fetched_at: usableForecast.fetched_at,
                      timezone: plant.profiles.timezone,
                      policy_version: 1,
                      policy: adjustment.policy,
                      forecast_date: adjustment.day.date,
                      rain_mm: adjustment.day.rain_mm,
                      rain_probability: adjustment.day.rain_probability,
                      temperature_max_c: adjustment.day.temperature_max_c,
                      is_mock: false,
                      attribution: "Weather data by Open-Meteo (CC BY 4.0)",
                    },
                  },
                });
              if (task.due_at <= now) {
                const inserted = await tx.notifications.createMany({
                  data: [
                    {
                      owner_id: ownerId,
                      event_key: eventKey,
                      kind: task.kind,
                      title:
                        task.kind === "water"
                          ? "Đến lịch kiểm tra tưới nước"
                          : "Đến lịch bón phân",
                      body: `${plant.nickname}: ${task.kind === "water" ? "kiểm tra độ ẩm đất trước khi tưới" : "kiểm tra hướng dẫn bón phân của cây"}.${task.adjustment_reason ? " " + task.adjustment_reason : ""}`.slice(
                        0,
                        4000,
                      ),
                      created_at: now,
                    },
                  ],
                  skipDuplicates: true,
                });
                addedNotifications += inserted.count;
              }
            }
            tasks.push(task);
          }
          return {
            plant_id: plantId,
            timezone: plant.profiles.timezone,
            tasks,
            notifications_created: addedNotifications,
            warnings,
            weather_source: usableForecast?.source ?? null,
          };
        },
        { timeout: 15000 },
      );
    },
  };
}
