import type { Database } from "../config/database.js";
import type { AuthenticatedUser } from "../middlewares/auth.js";

export interface PushDeviceInput {
  installation_id: string;
  token: string;
  platform: "android" | "ios";
}

export function pushDeviceService(db: Database) {
  return {
    async register(user: AuthenticatedUser, input: PushDeviceInput) {
      return db.$transaction(async (tx) => {
        // Serialize account switches and token rotations, including first registration.
        await tx.$queryRaw`SELECT true FROM pg_advisory_xact_lock(734103, 2)`;
        await tx.profiles.upsert({
          where: { id: user.id },
          create: { id: user.id, display_name: user.displayName },
          update: {},
        });
        const current = await tx.push_devices.findUnique({
          where: { installation_id: input.installation_id },
        });
        // Deleting the former binding cancels its queued deliveries on account switch.
        await tx.push_devices.deleteMany({
          where: {
            OR: [
              { installation_id: input.installation_id },
              { token: input.token },
            ],
            NOT: current?.owner_id === user.id ? { id: current.id } : undefined,
          },
        });
        return tx.push_devices.upsert({
          where: { installation_id: input.installation_id },
          create: { ...input, owner_id: user.id },
          update: {
            token: input.token,
            platform: input.platform,
            active: true,
            updated_at: new Date(),
          },
          select: {
            id: true,
            installation_id: true,
            platform: true,
            active: true,
          },
        });
      });
    },
    async remove(ownerId: string, id: string) {
      return db.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT true FROM pg_advisory_xact_lock(734103, 2)`;
        const result = await tx.push_devices.deleteMany({
          where: { id, owner_id: ownerId },
        });
        return { removed: result.count > 0 };
      });
    },
  };
}
