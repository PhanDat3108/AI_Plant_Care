import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";

export function healthService(db: Database) {
  return {
    async ready() {
      try {
        await db.profiles.count();
      } catch {
        throw new HttpError(
          503,
          "DATABASE_UNAVAILABLE",
          "Database chưa sẵn sàng hoặc chưa migrate.",
        );
      }
      return { status: "ready" };
    },
  };
}
