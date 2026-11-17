import type { Database } from "../config/database.js";
import type { carePlanner } from "./care-planner.js";

interface ReminderRunOptions {
  shouldStop?: () => boolean;
  onPlantError?: (plantId: string) => void;
}

export function reminderService(
  db: Database,
  planner: Pick<ReturnType<typeof carePlanner>, "sync">,
) {
  return {
    async runOnce(options: ReminderRunOptions = {}) {
      let processed = 0,
        failed = 0,
        notifications = 0;
      let after: string | undefined;
      while (!options.shouldStop?.()) {
        const plants = await db.plants.findMany({
          where: after ? { id: { gt: after } } : {},
          orderBy: { id: "asc" },
          take: 50,
          select: { id: true, owner_id: true },
        });
        if (!plants.length) break;
        for (const plant of plants) {
          if (options.shouldStop?.()) break;
          try {
            const result = await planner.sync(plant.owner_id, plant.id);
            processed++;
            notifications += result.notifications_created;
          } catch {
            failed++;
            options.onPlantError?.(plant.id);
          }
        }
        after = plants.at(-1)!.id;
      }
      return { processed, failed, notifications_created: notifications };
    },
  };
}
