import { Router } from "express";
import { z } from "zod";
import type { Config } from "../config/env.js";
import { authenticate } from "../middlewares/auth.js";
import { HttpError, success } from "../middlewares/errors.js";

const credentials = z.strictObject({
  email: z.email().max(254),
  password: z.string().min(1).max(256),
});
const newPassword = z.string().min(8).max(256);
const registration = credentials.extend({
  password: newPassword,
  full_name: z.string().trim().min(1).max(100),
});
const refresh = z.strictObject({ refresh_token: z.string().min(1).max(8192) });
const email = z.strictObject({ email: z.email().max(254) });
const exchange = z.strictObject({
  auth_code: z.string().min(1).max(4096),
  code_verifier: z.string().regex(/^[A-Za-z0-9._~-]{43,128}$/),
});
const google = z.strictObject({
  code_challenge: z.string().regex(/^[A-Za-z0-9_-]{43}$/),
});

export function authRoutes(config: Config) {
  const router = Router();
  // Never cache responses containing session credentials.
  router.use((_req, res, next) => {
    res.setHeader("Cache-Control", "no-store");
    next();
  });
  function base() {
    if (!config.SUPABASE_URL || !config.SUPABASE_PUBLISHABLE_KEY)
      throw new HttpError(
        503,
        "AUTH_UNAVAILABLE",
        "Chưa cấu hình Supabase Auth.",
      );
    return config.SUPABASE_URL;
  }
  function redirect() {
    if (!config.AUTH_REDIRECT_URL)
      throw new HttpError(
        503,
        "AUTH_REDIRECT_NOT_CONFIGURED",
        "Chưa cấu hình địa chỉ quay về ứng dụng.",
      );
    return config.AUTH_REDIRECT_URL;
  }
  async function call(
    path: string,
    body?: unknown,
    token?: string,
    method = "POST",
  ) {
    const url = new URL(`/auth/v1/${path}`, base());
    let response: Response;
    try {
      response = await fetch(url, {
        method,
        headers: {
          apikey: config.SUPABASE_PUBLISHABLE_KEY!,
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(10000),
      });
    } catch {
      throw new HttpError(
        503,
        "AUTH_UNAVAILABLE",
        "Chưa kết nối được dịch vụ xác thực.",
      );
    }
    if (!response.ok) {
      if (response.status === 429)
        throw new HttpError(
          429,
          "AUTH_RATE_LIMITED",
          "Quá nhiều yêu cầu. Vui lòng thử lại sau.",
        );
      if (response.status >= 500)
        throw new HttpError(
          503,
          "AUTH_UNAVAILABLE",
          "Dịch vụ xác thực chưa sẵn sàng.",
        );
      throw new HttpError(
        400,
        "AUTH_FAILED",
        "Yêu cầu xác thực không hợp lệ, tài khoản chưa xác nhận hoặc phiên đã hết hạn.",
      );
    }
    if (response.status === 204) return null;
    try {
      return await response.json();
    } catch {
      return null;
    }
  }
  function session(data: Record<string, unknown> | null) {
    if (!data?.access_token || !data.refresh_token)
      throw new HttpError(
        503,
        "AUTH_UNAVAILABLE",
        "Dịch vụ chưa trả về phiên hợp lệ.",
      );
    return {
      access_token: data.access_token,
      refresh_token: data.refresh_token,
      expires_in: data.expires_in,
      expires_at: data.expires_at,
      token_type: data.token_type,
      user: data.user,
    };
  }
  router.post("/register", async (req, res) => {
    const { email, password, full_name } = registration.parse(req.body);
    const data = await call(
      `signup?redirect_to=${encodeURIComponent(redirect())}`,
      { email, password, data: { full_name } },
    );
    // Return the same response for existing and new unconfirmed accounts.
    success(
      res,
      data?.access_token
        ? { session: session(data), confirmation_required: false }
        : {
            session: null,
            confirmation_required: true,
            message: "Kiểm tra email để xác nhận tài khoản nếu yêu cầu hợp lệ.",
          },
    );
  });
  router.post("/login", async (req, res) => {
    success(
      res,
      session(
        await call("token?grant_type=password", credentials.parse(req.body)),
      ),
    );
  });
  router.post("/refresh", async (req, res) => {
    success(
      res,
      session(
        await call("token?grant_type=refresh_token", refresh.parse(req.body)),
      ),
    );
  });
  router.post("/forgot-password", async (req, res) => {
    await call(
      `recover?redirect_to=${encodeURIComponent(redirect())}`,
      email.parse(req.body),
    );
    success(res, {
      message: "Nếu email hợp lệ, bạn sẽ nhận được hướng dẫn đặt lại mật khẩu.",
    });
  });
  router.post("/resend-confirmation", async (req, res) => {
    await call(`resend?redirect_to=${encodeURIComponent(redirect())}`, {
      ...email.parse(req.body),
      type: "signup",
    });
    success(res, { message: "Kiểm tra email nếu tài khoản cần xác nhận." });
  });
  router.post("/google", (req, res) => {
    const { code_challenge } = google.parse(req.body);
    const url = new URL("/auth/v1/authorize", base());
    url.searchParams.set("provider", "google");
    url.searchParams.set("redirect_to", redirect());
    url.searchParams.set("code_challenge", code_challenge);
    url.searchParams.set("code_challenge_method", "s256");
    success(res, { url: url.toString() });
  });
  router.post("/exchange-code", async (req, res) => {
    success(
      res,
      session(await call("token?grant_type=pkce", exchange.parse(req.body))),
    );
  });
  // Force real Supabase verification even when local garden demo mode is enabled.
  router.use(authenticate({ ...config, DEV_AUTH_BYPASS: false }));
  router.post("/reset-password", async (req, res) => {
    const body = z.strictObject({ password: newPassword }).parse(req.body);
    await call("user", body, req.get("authorization")!.split(/\s+/)[1], "PUT");
    success(res, { message: "Đã cập nhật mật khẩu." });
  });
  router.post("/logout", async (req, res) => {
    await call(
      "logout?scope=local",
      undefined,
      req.get("authorization")!.split(/\s+/)[1],
    );
    success(res, { message: "Đã đăng xuất phiên hiện tại." });
  });
  return router;
}
