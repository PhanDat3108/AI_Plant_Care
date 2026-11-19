import type { RequestHandler } from "express";
import { z } from "zod";
import type { Config } from "../config/env.js";
import { success } from "../middlewares/errors.js";
import { authService } from "../services/auth.js";

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

export function authController(config: Config) {
  const service = authService(config);
  const register: RequestHandler = async (req, res) => {
    success(res, await service.register(registration.parse(req.body)));
  };
  const login: RequestHandler = async (req, res) => {
    success(res, await service.login(credentials.parse(req.body)));
  };
  const refreshSession: RequestHandler = async (req, res) => {
    success(res, await service.refresh(refresh.parse(req.body)));
  };
  const forgotPassword: RequestHandler = async (req, res) => {
    success(res, await service.forgotPassword(email.parse(req.body)));
  };
  const resendConfirmation: RequestHandler = async (req, res) => {
    success(res, await service.resendConfirmation(email.parse(req.body)));
  };
  const googleLogin: RequestHandler = (req, res) => {
    success(res, service.google(google.parse(req.body)));
  };
  const exchangeCode: RequestHandler = async (req, res) => {
    success(res, await service.exchangeCode(exchange.parse(req.body)));
  };
  // These handlers are mounted only after the real Supabase authentication middleware.
  const resetPassword: RequestHandler = async (req, res) => {
    const body = z.strictObject({ password: newPassword }).parse(req.body);
    success(
      res,
      await service.resetPassword(
        body,
        req.get("authorization")!.split(/\s+/)[1],
      ),
    );
  };
  const logout: RequestHandler = async (req, res) => {
    success(
      res,
      await service.logout(req.get("authorization")!.split(/\s+/)[1]),
    );
  };
  return {
    register,
    login,
    refresh: refreshSession,
    forgotPassword,
    resendConfirmation,
    google: googleLogin,
    exchangeCode,
    resetPassword,
    logout,
  };
}
