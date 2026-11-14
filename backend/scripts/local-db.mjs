import "dotenv/config";
import { mkdir, access } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import EmbeddedPostgres from "embedded-postgres";
import { Client } from "pg";

const url = new URL(process.env.DATABASE_URL);
if (
  process.env.NODE_ENV !== "development" ||
  url.hostname !== "127.0.0.1" ||
  url.protocol !== "postgresql:"
) {
  throw new Error(
    "db:local yêu cầu NODE_ENV=development và DATABASE_URL PostgreSQL tại 127.0.0.1.",
  );
}
const root = fileURLToPath(new URL("../.local/", import.meta.url));
const data = root + "postgres";
await mkdir(root, { recursive: true });
const pg = new EmbeddedPostgres({
  databaseDir: data,
  user: decodeURIComponent(url.username),
  password: decodeURIComponent(url.password),
  port: Number(url.port || 5432),
  persistent: true,
  initdbFlags: ["--encoding=UTF8", "--locale=C"],
  postgresFlags: ["-h", "127.0.0.1", "-k", ""],
  onLog: () => {},
  onError: () => {},
});
let started = false;
try {
  let initialized = true;
  try {
    await access(data + "/PG_VERSION");
  } catch {
    initialized = false;
  }
  if (!initialized) await pg.initialise();
  await pg.start();
  started = true;
  const adminUrl = new URL(url);
  adminUrl.pathname = "/postgres";
  const client = new Client({
    connectionString: adminUrl.href,
    connectionTimeoutMillis: 5000,
  });
  try {
    await client.connect();
    const name = decodeURIComponent(url.pathname.slice(1));
    if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(name))
      throw new Error("Tên DB không hợp lệ.");
    const existing = await client.query(
      "SELECT 1 FROM pg_database WHERE datname=$1",
      [name],
    );
    if (!existing.rowCount)
      await client.query("CREATE DATABASE " + client.escapeIdentifier(name));
  } finally {
    await client.end();
  }
  console.log(
    "PostgreSQL local sẵn sàng ở cổng " +
      (url.port || 5432) +
      ". Dừng bằng Ctrl+C.",
  );
} catch {
  console.error(
    "Chưa khởi động được DB local. Kiểm tra cổng bị chiếm, mật khẩu trong .env và quyền ghi .local/.",
  );
  if (started) await pg.stop();
  process.exit(1);
}
let stopping = false;
async function stop() {
  if (stopping) return;
  stopping = true;
  await pg.stop();
}
process.on("SIGINT", () => void stop());
process.on("SIGTERM", () => void stop());
