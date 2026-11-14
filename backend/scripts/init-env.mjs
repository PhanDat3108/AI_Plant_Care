import { readFile, writeFile } from "node:fs/promises";
import { randomBytes } from "node:crypto";

const source = await readFile(
  new URL("../.env.example", import.meta.url),
  "utf8",
);
try {
  await writeFile(
    new URL("../.env", import.meta.url),
    source.replaceAll("CHANGE_ME", randomBytes(24).toString("hex")),
    { flag: "wx", mode: 0o600 },
  );
  console.log("Đã tạo backend/.env với mật khẩu local riêng.");
} catch (error) {
  if (error.code !== "EEXIST") throw error;
  console.log("backend/.env đã tồn tại.");
}
