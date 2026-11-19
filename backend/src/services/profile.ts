import type { Database } from "../config/database.js";
import type { AuthenticatedUser } from "../middlewares/auth.js";

export interface ProfileUpdate {
  display_name?: string;
  timezone?: string;
}

export function profileService(db: Database) {
  async function stats(userId: string) {
    const [total_plants, total_ai_scans, care] = await Promise.all([
      db.plants.count({ where: { owner_id: userId } }),
      db.scans.count({ where: { owner_id: userId } }),
      db.care_logs.groupBy({
        by: ["kind"],
        where: {
          plants: { owner_id: userId },
          kind: { in: ["water", "fertilize", "treat"] },
          performed_at: { lte: new Date() },
        },
        _count: { _all: true },
        _max: { performed_at: true },
      }),
    ]);
    const count = (kind: string) =>
      care.find((row) => row.kind === kind)?._count._all ?? 0;
    const last = care.reduce<Date | null>((latest, row) => {
      const date = row._max.performed_at;
      return date && (!latest || date > latest) ? date : latest;
    }, null);
    return {
      total_plants,
      total_ai_scans,
      care_stats: {
        total_actions: care.reduce((total, row) => total + row._count._all, 0),
        watering_count: count("water"),
        fertilizing_count: count("fertilize"),
        treatment_count: count("treat"),
        last_cared_at: last,
      },
    };
  }
  return {
    stats,
    async get(user: AuthenticatedUser) {
      // Repeated logins must not overwrite a name the user changed in the app.
      const profile = await db.profiles.upsert({
        where: { id: user.id },
        create: { id: user.id, display_name: user.displayName },
        update: {},
      });
      return {
        ...profile,
        email: user.email ?? null,
        avatar_url: user.avatarUrl ?? null,
        ...(await stats(user.id)),
        isDemo: user.isDemo,
      };
    },
    async update(user: AuthenticatedUser, changes: ProfileUpdate) {
      // A valid user can update their profile before their first GET /me.
      const profile = await db.profiles.upsert({
        where: { id: user.id },
        create: {
          id: user.id,
          display_name: changes.display_name ?? user.displayName,
          ...(changes.timezone ? { timezone: changes.timezone } : {}),
        },
        update: changes,
      });
      return { ...profile, isDemo: user.isDemo };
    },
  };
}
