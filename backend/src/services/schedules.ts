import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";

export interface ScheduleInput {
  interval_days: number;
  local_time: string;
  enabled: boolean;
}
export function scheduleService(db: Database) {
  const missing = () =>
    new HttpError(404, "NOT_FOUND", "Không tìm thấy cây của bạn.");
  return {
    async list(ownerId: string, plantId: string) {
      const plant = await db.plants.findFirst({
        where: { id: plantId, owner_id: ownerId },
        select: {
          profiles: { select: { timezone: true } },
          care_schedules: { orderBy: { kind: "asc" } },
        },
      });
      if (!plant) throw missing();
      return {
        timezone: plant.profiles.timezone,
        items: plant.care_schedules.map(serializeSchedule),
      };
    },
    async save(
      ownerId: string,
      plantId: string,
      kind: "water" | "fertilize",
      input: ScheduleInput,
    ) {
      return db.$transaction(async (tx) => {
        // Serialize schedule edits for this plant and prevent races with deletion.
        const rows = await tx.$queryRaw<
          { id: string }[]
        >`SELECT id FROM plantcare.plants WHERE id = ${plantId}::uuid AND owner_id = ${ownerId}::uuid FOR UPDATE`;
        if (!rows.length) throw missing();
        const previous = await tx.care_schedules.findUnique({
          where: { plant_id_kind: { plant_id: plantId, kind } },
        });
        const localTime = new Date(`1970-01-01T${input.local_time}:00.000Z`);
        const changed =
          previous &&
          (previous.interval_days !== input.interval_days ||
            previous.local_time.getTime() !== localTime.getTime() ||
            previous.enabled !== input.enabled);
        const schedule = await tx.care_schedules.upsert({
          where: { plant_id_kind: { plant_id: plantId, kind } },
          create: {
            plant_id: plantId,
            kind,
            interval_days: input.interval_days,
            local_time: localTime,
            enabled: input.enabled,
          },
          update: {
            interval_days: input.interval_days,
            local_time: localTime,
            enabled: input.enabled,
            ...(changed ? { starts_at: new Date() } : {}),
          },
        });
        // Old pending tasks no longer represent the rule; retain done/history rows.
        // The next planner pass creates a new task from starts_at.
        if (changed)
          await tx.care_tasks.updateMany({
            where: { schedule_id: schedule.id, state: "pending" },
            data: { state: "skipped" },
          });
        return serializeSchedule(schedule);
      });
    },
  };
}
function serializeSchedule<T extends { local_time: Date }>(schedule: T) {
  return {
    ...schedule,
    local_time: schedule.local_time.toISOString().slice(11, 16),
  };
}
