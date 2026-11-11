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
      DEV_AUTH_BYPASS: flag.prefault("false"),
      MOCK_EXTERNAL_APIS: flag.prefault("true"),
      CORS_ORIGINS: z
        .string()
        .default("")
        .transform((s) =>
          s
            .split(",")
            .map((v) => v.trim())
            .filter(Boolean),
        ),
      SUPABASE_URL: z
        .union([z.url({ protocol: /^https$/ }), z.literal("")])
        .optional(),
      SUPABASE_PUBLISHABLE_KEY: z.string().optional(),
      KINDWISE_API_KEY: z.string().optional(),
      PERENUAL_API_KEY: z.string().optional(),
    })
    .parse(input);
  if (config.DEV_AUTH_BYPASS && config.NODE_ENV !== "development")
    throw new Error("DEV_AUTH_BYPASS yêu cầu NODE_ENV=development");
  if (
    !config.MOCK_EXTERNAL_APIS &&
    (!config.KINDWISE_API_KEY || !config.PERENUAL_API_KEY)
  )
    throw new Error("Thiếu key của Kindwise hoặc Perenual");
  return config;
}
export type Config = ReturnType<typeof readConfig>;
