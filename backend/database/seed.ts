import { createDatabase } from "../src/config/database.js";
import { readConfig } from "../src/config/env.js";
import { demoUserId } from "../src/config/demo.js";

const config = readConfig(process.env);
if (config.NODE_ENV !== "development" || !config.DEV_AUTH_BYPASS) {
  throw new Error("Seed demo yêu cầu development và DEV_AUTH_BYPASS=true.");
}
const db = createDatabase(config.DATABASE_URL);
try {
  await db.$transaction(async (tx) => {
    await tx.profiles.upsert({
      where: { id: demoUserId },
      create: { id: demoUserId, display_name: "Người dùng demo" },
      update: {},
    });
    const samples = [
      {
        speciesId: "00000000-0000-4000-8100-000000000001",
        plantId: "00000000-0000-4000-8200-000000000001",
        scheduleId: "00000000-0000-4000-8300-000000000001",
        taskId: "00000000-0000-4000-8400-000000000001",
        scientificName: "Epipremnum aureum",
        name: "Trầu bà",
        days: 7,
      },
      {
        speciesId: "00000000-0000-4000-8100-000000000002",
        plantId: "00000000-0000-4000-8200-000000000002",
        scheduleId: "00000000-0000-4000-8300-000000000002",
        taskId: "00000000-0000-4000-8400-000000000002",
        scientificName: "Aloe vera",
        name: "Nha đam",
        days: 14,
      },
    ];
    for (const item of samples) {
      await tx.plant_species.upsert({
        where: { id: item.speciesId },
        create: {
          id: item.speciesId,
          scientific_name: item.scientificName,
          common_name: item.name,
          watering_days: item.days,
          care_source: "Dữ liệu demo để thử lịch",
        },
        update: {},
      });
      await tx.plants.upsert({
        where: { id: item.plantId },
        create: {
          id: item.plantId,
          owner_id: demoUserId,
          species_id: item.speciesId,
          nickname: item.name + " demo",
          environment: "indoor",
        },
        update: {},
      });
      await tx.care_schedules.upsert({
        where: { id: item.scheduleId },
        create: {
          id: item.scheduleId,
          plant_id: item.plantId,
          kind: "water",
          interval_days: item.days,
          local_time: new Date("1970-01-01T08:00:00Z"),
        },
        update: {},
      });
      const dueAt = new Date(Date.now() + 86400000);
      await tx.care_tasks.upsert({
        where: { id: item.taskId },
        create: {
          id: item.taskId,
          schedule_id: item.scheduleId,
          plant_id: item.plantId,
          kind: "water",
          due_at: dueAt,
          original_due_at: dueAt,
        },
        update: {},
      });
    }
  });
  console.info(
    "Đã seed 2 cây và 2 lịch mẫu. Chạy lại giữ các bản ghi hiện có.",
  );
} finally {
  await db.$disconnect();
}
