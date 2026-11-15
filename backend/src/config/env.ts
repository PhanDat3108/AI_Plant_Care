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
      AUTH_REDIRECT_URL: z.union([z.url(), z.literal("")]).optional(),
    })
    .parse(input);

  if (config.DEV_AUTH_BYPASS && config.NODE_ENV !== "development") {
    throw new Error("DEV_AUTH_BYPASS chỉ được bật trong development.");
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
