import { readConfig } from "../config/env.js";
import { firebasePushSender } from "../config/firebase.js";

const config = readConfig(process.env);
if (!config.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error("Thiếu GOOGLE_APPLICATION_CREDENTIALS.");
  process.exitCode = 1;
} else {
  try {
    const send = firebasePushSender({ PUSH_ENABLED: true }, true)!;
    await send({
      topic: "plantcare-setup-check",
      notification: { title: "Kiểm tra cấu hình", body: "FCM validation only" },
    });
    console.info("FCM_OK: xác thực và quyền gửi hợp lệ; dry_run=true.");
  } catch (error) {
    const code = (error as { code?: unknown })?.code;
    console.error(
      typeof code === "string" && /^(app|messaging)\/[a-z-]+$/.test(code)
        ? code
        : "FCM_CHECK_FAILED",
    );
    process.exitCode = 1;
  }
}
