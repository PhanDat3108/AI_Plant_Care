import type { Config } from "../config/env.js";
import { HttpError } from "../middlewares/errors.js";

interface Credentials {
  email: string;
  password: string;
}
interface Registration extends Credentials {
  full_name: string;
}
interface CodeExchange {
  auth_code: string;
  code_verifier: string;
}

export function authService(config: Config) {
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
      const data: unknown = await response.json();
      if (!data || typeof data !== "object" || Array.isArray(data)) {
        throw new Error("Invalid Auth response");
      }
      return data as Record<string, unknown>;
    } catch {
      throw new HttpError(
        503,
        "AUTH_UNAVAILABLE",
        "Dịch vụ xác thực trả về dữ liệu không hợp lệ.",
      );
    }
  }
  function session(data: Record<string, unknown> | null) {
    if (
      typeof data?.access_token !== "string" || !data.access_token.trim() ||
      typeof data.refresh_token !== "string" || !data.refresh_token.trim()
    )
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
  return {
    async register({ email, password, full_name }: Registration) {
      const data = await call(
        `signup?redirect_to=${encodeURIComponent(redirect())}`,
        {
          email,
          password,
          data: { full_name },
        },
      );
      // A malformed success must not masquerade as a confirmation email being sent.
      if (!data || (!data.access_token && !data.refresh_token &&
          (typeof data.id !== "string" || !data.id.trim()))) {
        throw new HttpError(503, "AUTH_UNAVAILABLE", "Dịch vụ xác thực trả về dữ liệu không hợp lệ.");
      }
      // Do not return account details for registrations without a session.
      return data.access_token !== undefined || data.refresh_token !== undefined
        ? { session: session(data), confirmation_required: false }
        : {
            session: null,
            confirmation_required: true,
            message: "Kiểm tra email để xác nhận tài khoản nếu yêu cầu hợp lệ.",
          };
    },
    async login(body: Credentials) {
      return session(await call("token?grant_type=password", body));
    },
    async refresh(body: { refresh_token: string }) {
      return session(await call("token?grant_type=refresh_token", body));
    },
    async forgotPassword(body: { email: string }) {
      await call(`recover?redirect_to=${encodeURIComponent(redirect())}`, body);
      return {
        message:
          "Nếu email hợp lệ, bạn sẽ nhận được hướng dẫn đặt lại mật khẩu.",
      };
    },
    async resendConfirmation(body: { email: string }) {
      await call(`resend?redirect_to=${encodeURIComponent(redirect())}`, {
        ...body,
        type: "signup",
      });
      return { message: "Kiểm tra email nếu tài khoản cần xác nhận." };
    },
    google({ code_challenge }: { code_challenge: string }) {
      const url = new URL("/auth/v1/authorize", base());
      url.searchParams.set("provider", "google");
      url.searchParams.set(
        "redirect_to",
        config.GOOGLE_AUTH_REDIRECT_URL || redirect(),
      );
      url.searchParams.set("code_challenge", code_challenge);
      url.searchParams.set("code_challenge_method", "s256");
      return { url: url.toString() };
    },
    async exchangeCode(body: CodeExchange) {
      return session(await call("token?grant_type=pkce", body));
    },
    async resetPassword(body: { password: string }, token: string) {
      await call("user", body, token, "PUT");
      return { message: "Đã cập nhật mật khẩu." };
    },
    async logout(token: string) {
      await call("logout?scope=local", undefined, token);
      return { message: "Đã đăng xuất phiên hiện tại." };
    },
  };
}
