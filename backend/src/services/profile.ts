import type { Database } from "../config/database.js";
import type { AuthenticatedUser } from "../middlewares/auth.js";

export interface ProfileUpdate {
  display_name?: string;
  timezone?: string;
}

export function profileService(db: Database) {
  return {
    async stats(userId: string) {
      const [total_plants, total_ai_scans] = await Promise.all([
        db.plants.count({ where: { owner_id: userId } }),
        db.scans.count({ where: { owner_id: userId } }),
      ]);
      return { total_plants, total_ai_scans };
    },
    get(user: AuthenticatedUser) {
      // Repeated logins must not overwrite a name the user changed in the app.
      return db.profiles.upsert({
        where: { id: user.id },
        create: { id: user.id, display_name: user.displayName },
        update: {},
      });
    },
    update(user: AuthenticatedUser, changes: ProfileUpdate) {
      // A valid user can update their profile before their first GET /me.
      return db.profiles.upsert({
        where: { id: user.id },
        create: {
          id: user.id,
          display_name: changes.display_name ?? user.displayName,
          ...(changes.timezone ? { timezone: changes.timezone } : {}),
        },
        update: changes,
      });
    },
  };
}
