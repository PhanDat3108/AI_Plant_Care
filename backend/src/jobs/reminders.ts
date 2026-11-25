import { firebasePushSender } from "../config/firebase.js";
import { pushNotificationService } from "../services/push-notifications.js";
import { reminderService } from "../services/reminders.js";
import { readConfig } from "../config/env.js";
import { createDatabase } from "../config/database.js";
import { carePlanner } from "../services/care-planner.js";
import { openMeteoProvider } from "../services/weather.js";

const config = readConfig(process.env);
const db = createDatabase(config.DATABASE_URL);
const planner = carePlanner(db, openMeteoProvider());
const service = reminderService(db, planner);
const push = pushNotificationService(db, firebasePushSender(config));
const watch = process.argv.includes("--watch");
let stopped = false;
let wake: (() => void) | undefined;
for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    stopped = true;
    wake?.();
  });
}

try {
  do {
    const result = await service.runOnce({
      shouldStop: () => stopped,
      onPlantError: (plantId) =>
        console.error("Không đồng bộ được lịch cây", plantId),
    });
    const pushResult = await push.run();
    console.info(JSON.stringify({ ...result, push: pushResult }));
    if (!watch) {
      if (result.failed) process.exitCode = 1;
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
