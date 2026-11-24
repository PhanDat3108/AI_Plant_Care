import "dotenv/config";
import { z } from "zod";

const flag = z.enum(["true", "false"]).transform((value) => value === "true");
export function readConfig(input: NodeJS.ProcessEnv) {
  const config = z
    .object({
      NODE_ENV: z
        .enum(["development", "test", "staging", "production"])
        .default("production"),
      PORT: z.coerce.number().int().min(1).max(65535).default(3100),
      DATABASE_URL: z.string().regex(/^postgres(ql)?:\/\//),
      CORS_ORIGINS: z
        .string()
        .default("")
        .transform((value) =>
          value
            .split(",")
            .map((v) => v.trim())
            .filter(Boolean),
        ),
      DEV_AUTH_BYPASS: flag.prefault("false"),
      SUPABASE_URL: z
        .union([z.url({ protocol: /^https$/ }), z.literal("")])
        .optional(),
      SUPABASE_PUBLISHABLE_KEY: z.string().optional(),
      SUPABASE_STORAGE_BUCKET: z.string().trim().default("plant-images"),
      SUPABASE_SECRET_KEY: z.string().trim().default(""),
      GOOGLE_AUTH_REDIRECT_URL: z.union([z.url(), z.literal("")]).optional(),
      AUTH_REDIRECT_URL: z.union([z.url(), z.literal("")]).optional(),
      CRON_SECRET: z
        .union([z.string().min(32).max(256), z.literal("")])
        .optional(),
      CARE_AI_MODE: z.enum(["auto", "demo", "live"]).default("auto"),
      GEMINI_API_KEY: z.string().trim().default(""),
      PLANTNET_API_KEY: z.string().trim().default(""),
      PLANTNET_PROJECT: z.string().trim().default("all"),
      UPLOAD_DIR: z.string().trim().default("uploads"),
      GEMINI_MODEL: z
        .string()
        .regex(/^[a-zA-Z0-9._-]{1,100}$/)
        .default("gemini-3.5-flash-lite"),
      CARE_REVIEWER_IDS: z
        .string()
        .default("")
        .transform((value) =>
          z.array(z.uuid()).parse(
            value
              .split(",")
              .map((id) => id.trim())
              .filter(Boolean),
          ),
        ),
    })
    .parse(input);

  if (config.DEV_AUTH_BYPASS && config.NODE_ENV !== "development") {
    throw new Error("DEV_AUTH_BYPASS chỉ được bật trong development.");
  }
  if (config.CARE_AI_MODE === "live" && !config.GEMINI_API_KEY) {
    throw new Error("CARE_AI_MODE=live cần GEMINI_API_KEY.");
  }
  if (
    ["production", "staging"].includes(config.NODE_ENV) &&
    (!config.SUPABASE_URL || !config.SUPABASE_PUBLISHABLE_KEY)
  ) {
    throw new Error("Môi trường triển khai cần cấu hình Supabase Auth.");
  }
  return config;
}
export type Config = ReturnType<typeof readConfig>;
