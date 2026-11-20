import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";
import { carePlanner } from "./care-planner.js";
import { openMeteoProvider } from "./weather.js";
import { reminderService } from "./reminders.js";

export function scheduledReminderService(db: Database) {
  const runner = reminderService(db, carePlanner(db, openMeteoProvider()));
  return {
    async run() {
      // Transaction-scoped lock is released even if this instance crashes.
      // The runner uses its own transactions, preserving existing per-plant commits.
      return db.$transaction(
        async (tx) => {
          const [lock] = await tx.$queryRaw<{ locked: boolean }[]>`
          SELECT pg_try_advisory_xact_lock(734102, 1) AS locked
        `;
          if (!lock?.locked)
            return { skipped: true, reason: "ALREADY_RUNNING" };
          const result = await runner.runOnce();
          if (result.failed) {
            throw new HttpError(
              503,
              "REMINDER_RUN_INCOMPLETE",
              "Một số cây chưa đồng bộ được. Có thể thử lại.",
            );
          }
          return { skipped: false, ...result };
        },
        { timeout: 120_000, maxWait: 5_000 },
      );
    },
  };
}
