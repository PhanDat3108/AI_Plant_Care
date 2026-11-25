import { randomUUID } from "node:crypto";
import type { Database } from "../config/database.js";
import type { PushSender } from "../config/firebase.js";

const maxAttempts = 8;
const batchSize = 20;
const invalidTokens = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);
const permanentErrors = new Set([
  "messaging/invalid-argument",
  "messaging/invalid-payload",
  "messaging/mismatched-credential",
]);

export function pushNotificationService(
  db: Database,
  send: PushSender | null,
  clock = () => new Date(),
) {
  return {
    async run() {
      if (!send)
        return {
          enabled: false,
          claimed: 0,
          sent: 0,
          retry: 0,
          failed: 0,
          skipped: 0,
        };
      const now = clock();
      const leaseId = randomUUID();
      const lockedUntil = new Date(now.getTime() + 15 * 60_000);
      await db.push_deliveries.updateMany({
        where: {
          OR: [
            { status: "pending", expires_at: { lte: now } },
            {
              status: "processing",
              locked_until: { lte: now },
              expires_at: { lte: now },
            },
            {
              status: "processing",
              locked_until: { lte: now },
              attempts: { gte: maxAttempts },
            },
          ],
        },
        data: {
          status: "failed",
          last_error: "EXPIRED_OR_RETRY_LIMIT",
          lease_id: null,
          locked_until: null,
        },
      });
      // Each SQL statement claims rows atomically, so concurrent cron/CLI runs are safe.
      const claimed = await db.$queryRaw<{ id: string }[]>`
        WITH candidates AS (
          SELECT id FROM plantcare.push_deliveries
          WHERE expires_at > ${now} AND attempts < ${maxAttempts}
            AND ((status = 'pending' AND available_at <= ${now})
              OR (status = 'processing' AND locked_until <= ${now}))
          ORDER BY available_at, id
          LIMIT ${batchSize}
          FOR UPDATE SKIP LOCKED
        )
        UPDATE plantcare.push_deliveries p
        SET status='processing', attempts=p.attempts+1,
            lease_id=${leaseId}::uuid, locked_until=${lockedUntil}
        FROM candidates c WHERE p.id=c.id RETURNING p.id
      `;
      const outcomes = await Promise.all(
        claimed.map(async ({ id }) => {
          const delivery = await db.push_deliveries.findFirst({
            where: { id, lease_id: leaseId, status: "processing" },
            include: { notifications: true, push_devices: true },
          });
          if (!delivery) return "skipped" as const;
          const notification = delivery.notifications;
          const device = delivery.push_devices;
          const finish = (status: string, lastError: string | null = null) =>
            db.push_deliveries.updateMany({
              where: { id, lease_id: leaseId, status: "processing" },
              data: {
                status,
                last_error: lastError,
                lease_id: null,
                locked_until: null,
                ...(status === "sent" ? { sent_at: clock() } : {}),
              },
            });
          const task = await db.care_tasks.findFirst({
            where: {
              id: notification.event_key?.slice("care-task:".length),
              state: "pending",
              due_at: { lte: now },
              care_schedules: {
                enabled: true,
                plants: { owner_id: delivery.owner_id },
              },
            },
            select: { id: true },
          });
          if (!device.active || notification.read_at || !task) {
            await finish("skipped", "NO_LONGER_APPLICABLE");
            return "skipped" as const;
          }

          // The SDK call is outside a DB transaction. Android tag replaces a repeated alert.
          try {
            await send({
              token: device.token,
              notification: {
                title: notification.title,
                body: notification.body.slice(0, 500),
              },
              data: {
                notification_id: notification.id,
                kind: notification.kind,
                screen: "notifications",
              },
              android: {
                priority: "high",
                ttl: Math.max(0, delivery.expires_at.getTime() - now.getTime()),
                notification: { tag: notification.id },
              },
              apns: {
                headers: {
                  "apns-collapse-id": notification.id,
                  "apns-expiration": String(
                    Math.floor(delivery.expires_at.getTime() / 1000),
                  ),
                },
              },
            });
          } catch (error) {
            const rawCode = (error as { code?: unknown })?.code;
            const code =
              typeof rawCode === "string" &&
              /^messaging\/[a-z-]+$/.test(rawCode)
                ? rawCode
                : "PUSH_PROVIDER_UNAVAILABLE";
            if (invalidTokens.has(code)) {
              // A refreshed token on the same installation must survive an old send failure.
              const disabled = await db.push_devices.updateMany({
                where: { id: device.id, token: device.token },
                data: { active: false, updated_at: clock() },
              });
              if (disabled.count) {
                await finish("failed", code);
                return "failed" as const;
              }
            }
            if (permanentErrors.has(code) || delivery.attempts >= maxAttempts) {
              await finish("failed", code);
              return "failed" as const;
            }
            const availableAt = new Date(
              clock().getTime() +
                Math.min(60 * 60_000, 60_000 * 2 ** (delivery.attempts - 1)),
            );
            await db.push_deliveries.updateMany({
              where: { id, lease_id: leaseId, status: "processing" },
              data: {
                status: "pending",
                last_error: code,
                available_at: availableAt,
                lease_id: null,
                locked_until: null,
              },
            });
            return "retry" as const;
          }
          // If this write fails after FCM accepted, lease recovery can resend; clients dedupe by ID.
          await finish("sent");
          return "sent" as const;
        }),
      );
      return {
        enabled: true,
        claimed: claimed.length,
        sent: outcomes.filter((value) => value === "sent").length,
        retry: outcomes.filter((value) => value === "retry").length,
        failed: outcomes.filter((value) => value === "failed").length,
        skipped: outcomes.filter((value) => value === "skipped").length,
      };
    },
  };
}
