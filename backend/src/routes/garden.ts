import { Router } from "express";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import { authenticate } from "../middlewares/auth.js";
import { gardenController } from "../controllers/garden.js";

/**
 * Khởi tạo Router quản lý vườn cây của người dùng.
 * @param db Database Prisma Client
 * @param config Cấu hình ứng dụng (để áp dụng middleware authenticate nếu cần)
 */
export function gardenRoutes(db: Database, config?: Config): Router {
  const router = Router();

  // Áp dụng middleware xác thực token nếu có truyền config
  if (config) {
    router.use(authenticate(config));
  }

  // Khởi tạo controller với kết nối database
  const garden = gardenController(db);

  /**
   * POST /
   * Thêm một cây mới vào vườn của user (status 201).
   */
  router.post("/", garden.addPlant);

  /**
   * GET /
   * Xem danh sách cây trong vườn của user (status 200).
   */
  router.get("/", garden.getGarden);

  /**
   * PATCH /:id/nickname
   * Sửa biệt danh cây (status 200).
   */
  router.patch("/:id/nickname", garden.updateNickname);

  /**
   * DELETE /:id
   * Xóa cây khỏi vườn (status 200).
   */
  router.delete("/:id", garden.removePlant);

  return router;
}
