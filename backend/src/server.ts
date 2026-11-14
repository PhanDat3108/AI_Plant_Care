import { createApp } from "./app.js";
import { readConfig } from "./config/env.js";
import { createDatabase } from "./config/database.js";

const config = readConfig(process.env);
const db = createDatabase(config.DATABASE_URL);
try {
  await db.$connect();
  const server = createApp(config, db).listen(config.PORT, "0.0.0.0", () =>
    console.info("AI Plant Care API đang chạy ở cổng", config.PORT),
  );
  server.on("error", async () => {
    console.error("Không mở được cổng API. Kiểm tra PORT.");
    await db.$disconnect();
    process.exitCode = 1;
  });
  let closing = false;
  function shutdown() {
    if (closing) return;
    closing = true;
    const deadline = setTimeout(() => process.exit(1), 10000);
    deadline.unref();
    server.close(() => {
      void db.$disconnect().then(() => {
        clearTimeout(deadline);
      });
    });
  }
  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
} catch {
  console.error(
    "Chưa kết nối được PostgreSQL. Kiểm tra DATABASE_URL và dịch vụ DB.",
  );
  await db.$disconnect();
  process.exitCode = 1;
}
