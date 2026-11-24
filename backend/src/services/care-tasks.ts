import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { dayBounds, localDate } from "./care-policy.js";
import { plantImageStorage } from "./plant-image-storage.js";

export interface CareTaskQuery {
  date?: string;
  state: "pending" | "done" | "skipped";
  limit: number;
  offset: number;
}

export function careTaskService(db: Database, config?: Config) {
  return {
    async list(userId: string, input: CareTaskQuery) {
      const profile = await db.profiles.findUnique({
        where: { id: userId },
        select: { timezone: true },
      });
      const timezone = profile?.timezone ?? "Asia/Ho_Chi_Minh";
      const date = input.date ?? localDate(new Date(), timezone).toString();
      const { from, to } = dayBounds(date, timezone);
      const items = await db.care_tasks.findMany({
        where: {
          state: input.state,
          due_at: { gte: from, lt: to },
          care_schedules: {
            plants: { owner_id: userId },
            ...(input.state === "pending" ? { enabled: true } : {}),
          },
        },
        orderBy: [{ due_at: "asc" }, { id: "asc" }],
        take: input.limit,
        skip: input.offset,
        include: {
          care_schedules: {
            select: {
              plants: {
                select: {
                  id: true,
                  nickname: true,
                  cover_image_key: true,
                  reference_images: {
                    select: {
                      image_url: true,
                      attribution: true,
                      source_url: true,
                    },
                  },
                },
              },
            },
          },
        },
      });

      if (config) {
        const storage = plantImageStorage(config);
        const keys = items
          .map((item) => item.care_schedules.plants?.cover_image_key)
          .filter((k): k is string => Boolean(k));
        const urlMap = await storage.createSignedUrls(keys);
        const enrichedItems = items.map((item) => {
          const plant = item.care_schedules.plants;
          return {
            ...item,
            care_schedules: {
              ...item.care_schedules,
              plants: plant
                ? {
                    ...plant,
                    cover_image_url: plant.cover_image_key
                      ? (urlMap.get(plant.cover_image_key) ?? null)
                      : null,
                  }
                : null,
            },
          };
        });
        return { date, timezone, items: enrichedItems };
      }

      const enrichedItems = items.map((item) => {
        const plant = item.care_schedules.plants;
        return {
          ...item,
          care_schedules: {
            ...item.care_schedules,
            plants: plant
              ? {
                  ...plant,
                  cover_image_url: null,
                }
              : null,
          },
        };
      });

      return { date, timezone, items: enrichedItems };
    },
  };
}
