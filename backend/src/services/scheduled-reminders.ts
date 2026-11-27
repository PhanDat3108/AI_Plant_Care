import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";
import { carePlanner } from "./care-planner.js";
import { sharedOpenMeteoProvider } from "./weather.js";
import { reminderService } from "./reminders.js";

export function scheduledReminderService(
  db: Database,
  push?: { run: () => Promise<unknown> },
) {
  const runner = reminderService(db, carePlanner(db, sharedOpenMeteoProvider()));
  return {
    async run() {
      // Transaction-scoped lock is released even if this instance crashes.
      // The runner uses its own transactions, preserving existing per-plant commits.
      const result = await db.$transaction(
        async (tx) => {
          const [lock] = await tx.$queryRaw<{ locked: boolean }[]>`
          SELECT pg_try_advisory_xact_lock(734102, 1) AS locked
        `;
          if (!lock?.locked)
            return { skipped: true, reason: "ALREADY_RUNNING" };
          const result = await runner.runOnce();
          return { skipped: false, ...result };
        },
        { timeout: 120_000, maxWait: 5_000 },
      );
      // Release the reminder transaction before network calls. Drain pending pushes even
      // when another reminder run holds the lock or some plants failed to synchronize.
      const delivery = await push?.run();
      if ("failed" in result && result.failed) {
        throw new HttpError(
          503,
          "REMINDER_RUN_INCOMPLETE",
          "Một số cây chưa đồng bộ được. Có thể thử lại.",
        );
      }
      return { ...result, ...(delivery ? { push: delivery } : {}) };
    },
  };
}
