import { Router } from "express";
import type { Database } from "../config/database.js";
import { careLogsController } from "../controllers/care-logs.js";

/**
 * Router quản lý nhật ký chăm sóc cây (Care Logs)
 */
export function careLogsRoutes(db: Database): Router {
  const router = Router();
  const controller = careLogsController(db);

  // Ghi nhận lần tưới nước / chữa bệnh / chăm sóc mới
  router.post("/plants/:id/care-logs", controller.create);

  // Xem lịch sử chăm sóc và tiến triển của cây
  router.get("/plants/:id/care-logs", controller.list);

  // Sửa ghi chú hoặc thông tin nhật ký
  router.patch("/care-logs/:logId", controller.update);

  // Xóa một mục nhật ký
  router.delete("/care-logs/:logId", controller.remove);

  return router;
}
