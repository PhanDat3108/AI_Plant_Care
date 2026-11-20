import { readFileSync } from "node:fs";
import { z } from "zod";
import { readConfig } from "../src/config/env.js";
import { createDatabase } from "../src/config/database.js";
import { seedExamples } from "./example-data.js";

const config = readConfig(process.env);
const db = createDatabase(config.DATABASE_URL);
let token: string | undefined;
async function main() {
  const args = process.argv.slice(2);
  let owner = args[0] === "--owner" ? z.uuid().parse(args[1]) : undefined;
  if (args[0] === "--account-file") {
    const credentials = z
      .object({ email: z.email(), password: z.string().min(1) })
      .parse(JSON.parse(readFileSync(args[1], "utf8")));
    const response = await fetch(
      "https://ai-plant-care.onrender.com/api/v1/auth/login",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(credentials),
        signal: AbortSignal.timeout(90000),
      },
    );
    const body = await response.json();
    if (!response.ok || !body.data?.user?.id || !body.data?.access_token)
      throw new Error("Không đăng nhập được tài khoản test.");
    owner = z.uuid().parse(body.data.user.id);
    token = body.data.access_token;
  }
  if (!owner)
    throw new Error(
      "Dùng --owner UUID hoặc --account-file /đường/dẫn/file-riêng.json",
    );
  console.info("Bộ dữ liệu mẫu đã sẵn sàng:", await seedExamples(db, owner));
}
try {
  await main();
} catch (error) {
  console.error(
    "Seed thất bại; kiểm tra cấu hình DB, tài khoản và migration. Không in thông tin bí mật.",
  );
  console.error(
    "Mã lỗi:",
    error instanceof Error ? error.name : "UNKNOWN",
    (error as { code?: string }).code ?? "",
  );
  process.exitCode = 1;
} finally {
  if (token)
    await fetch("https://ai-plant-care.onrender.com/api/v1/auth/logout", {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
    }).catch(() => {});
  await db.$disconnect();
}
