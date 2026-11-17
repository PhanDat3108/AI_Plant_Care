import { readConfig } from "../config/env.js";
import { createDatabase } from "../config/database.js";
import { carePlanner } from "../services/care-planner.js";
import { openMeteoProvider } from "../services/weather.js";

const config = readConfig(process.env);
const db = createDatabase(config.DATABASE_URL);
const planner = carePlanner(db, openMeteoProvider());
const watch = process.argv.includes("--watch");
let stopped = false;
let wake: (() => void) | undefined;
for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    stopped = true;
    wake?.();
  });
}
async function runOnce() {
  let processed = 0,
    failed = 0,
    notifications = 0;
  let after: string | undefined;
  while (!stopped) {
    const plants = await db.plants.findMany({
      where: after ? { id: { gt: after } } : {},
      orderBy: { id: "asc" },
      take: 50,
      select: { id: true, owner_id: true },
    });
    if (!plants.length) break;
    for (const plant of plants) {
      if (stopped) break;
      try {
        const result = await planner.sync(plant.owner_id, plant.id);
        processed++;
        notifications += result.notifications_created;
      } catch {
        failed++;
        console.error("Không đồng bộ được lịch cây", plant.id);
      }
    }
    after = plants.at(-1)!.id;
  }
  console.info(
    JSON.stringify({ processed, failed, notifications_created: notifications }),
  );
  return failed;
}
try {
  do {
    const failed = await runOnce();
    if (!watch) {
      if (failed) process.exitCode = 1;
      break;
    }
    if (!stopped)
      await new Promise<void>((resolve) => {
        const timer = setTimeout(() => {
          wake = undefined;
          resolve();
        }, 60_000);
        wake = () => {
          clearTimeout(timer);
          wake = undefined;
          resolve();
        };
      });
  } while (!stopped);
} catch {
  console.error("Tác vụ nhắc chăm sóc dừng vì lỗi database/cấu hình.");
  process.exitCode = 1;
} finally {
  await db.$disconnect();
}
