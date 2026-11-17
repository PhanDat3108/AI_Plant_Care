// Never reads or writes the shared Supabase DB. Each run owns a disposable cluster.
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomBytes } from "node:crypto";
import { createServer } from "node:net";
import { spawn } from "node:child_process";
import EmbeddedPostgres from "embedded-postgres";
const dir = await mkdtemp(join(tmpdir(), "plantcare-test-"));
const listener = createServer();
await new Promise((r) => listener.listen(0, "127.0.0.1", r));
const port = listener.address().port;
await new Promise((r) => listener.close(r));
const password = randomBytes(24).toString("hex");
const pg = new EmbeddedPostgres({
  databaseDir: dir,
  user: "test",
  password,
  port,
  persistent: false,
  initdbFlags: ["--encoding=UTF8", "--locale=C"],
  postgresFlags: ["-h", "127.0.0.1", "-k", ""],
  onLog: () => {},
  onError: () => {},
});
const url = `postgresql://test:${password}@127.0.0.1:${port}/postgres`;
const env = {
  ...process.env,
  DATABASE_URL: url,
  DIRECT_URL: url,
  NODE_ENV: "test",
};
async function run(args) {
  await new Promise((resolve, reject) => {
    const child = spawn(process.execPath, args, { env, stdio: "inherit" });
    child.on("error", reject);
    child.on("exit", (code) =>
      code === 0 ? resolve() : reject(new Error(`Check failed (${code})`)),
    );
  });
}
let started = false;
try {
  await pg.initialise();
  await pg.start();
  started = true;
  await run(["node_modules/prisma/build/index.js", "migrate", "deploy"]);
  await run(["node_modules/vitest/vitest.mjs", "run", "tests/database"]);
} finally {
  if (started) await pg.stop();
  await rm(dir, { recursive: true, force: true });
}
