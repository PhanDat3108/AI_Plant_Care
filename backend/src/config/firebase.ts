import { applicationDefault, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging, type Message } from "firebase-admin/messaging";
import type { Config } from "./env.js";

export type PushSender = (message: Message) => Promise<string>;

export function firebasePushSender(
  config: Pick<Config, "PUSH_ENABLED">,
  dryRun = false,
): PushSender | null {
  if (!config.PUSH_ENABLED) return null;
  // Lazy initialization allows the inbox and health endpoints to run independently.
  return async (message) => {
    const app =
      getApps().find((item) => item.name === "plantcare-push") ??
      initializeApp({ credential: applicationDefault() }, "plantcare-push");
    return getMessaging(app).send(message, dryRun);
  };
}
