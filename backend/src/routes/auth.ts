import { Router } from "express";
import type { Config } from "../config/env.js";
import { authController } from "../controllers/auth.js";
import { authenticate } from "../middlewares/auth.js";
import { authNoStore } from "../middlewares/auth-no-store.js";

export function authRoutes(config: Config) {
  const router = Router();
  const controller = authController(config);
  router.use(authNoStore);
  router.post("/register", controller.register);
  router.post("/login", controller.login);
  router.post("/refresh", controller.refresh);
  router.post("/forgot-password", controller.forgotPassword);
  router.post("/resend-confirmation", controller.resendConfirmation);
  router.post("/google", controller.google);
  router.post("/exchange-code", controller.exchangeCode);
  // Recovery/password changes and logout always require a real Supabase session.
  router.use(authenticate({ ...config, DEV_AUTH_BYPASS: false }));
  router.post("/reset-password", controller.resetPassword);
  router.post("/logout", controller.logout);
  return router;
}
