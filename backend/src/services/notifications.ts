import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";
export interface NotificationCursor {
  created_at: string;
  id: string;
}
export function notificationService(db: Database) {
  return {
    async list(
      ownerId: string,
      limit: number,
      unreadOnly: boolean,
      cursor?: NotificationCursor,
    ) {
      const rows = await db.notifications.findMany({
        where: {
          owner_id: ownerId,
          ...(unreadOnly ? { read_at: null } : {}),
          ...(cursor
            ? {
                OR: [
                  { created_at: { lt: new Date(cursor.created_at) } },
                  {
                    created_at: new Date(cursor.created_at),
                    id: { lt: cursor.id },
                  },
                ],
              }
            : {}),
        },
        orderBy: [{ created_at: "desc" }, { id: "desc" }],
        take: limit + 1,
        select: {
          id: true,
          kind: true,
          title: true,
          body: true,
          created_at: true,
          read_at: true,
        },
      });
      const items = rows.slice(0, limit);
      const last = items.at(-1);
      return {
        items,
        next_cursor:
          rows.length > limit && last
            ? Buffer.from(
                JSON.stringify({
                  created_at: last.created_at.toISOString(),
                  id: last.id,
                }),
              ).toString("base64url")
            : null,
      };
    },
    async unreadCount(ownerId: string) {
      return {
        unread_count: await db.notifications.count({
          where: { owner_id: ownerId, read_at: null },
        }),
      };
    },
    async markRead(ownerId: string, id: string) {
      return db.$transaction(async (tx) => {
        await tx.notifications.updateMany({
          where: { id, owner_id: ownerId, read_at: null },
          data: { read_at: new Date() },
        });
        const item = await tx.notifications.findFirst({
          where: { id, owner_id: ownerId },
          select: { id: true, read_at: true },
        });
        if (!item)
          throw new HttpError(
            404,
            "NOT_FOUND",
            "Không tìm thấy thông báo của bạn.",
          );
        return item;
      });
    },
  };
}
