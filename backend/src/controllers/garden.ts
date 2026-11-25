import type { Request, Response, RequestHandler } from "express";
import { z } from "zod";
import type { Database } from "../config/database.js";
import type { Config } from "../config/env.js";
import {
  gardenService,
  addPlant as addPlantService,
  getGardenPlants as getGardenPlantsService,
  updatePlantNickname as updateNicknameService,
  removePlant as removePlantService,
} from "../services/garden.js";
import { HttpError, success } from "../middlewares/errors.js";

/**
 * Trợ giúp lấy userId từ req.user hoặc res.locals.user (hỗ trợ cả hai cơ chế middleware)
 */
function getUserId(req: Request, res: Response): string {
  const user = (req as Request & { user?: { id: string } }).user || res.locals?.user;
  if (!user?.id) {
    throw new HttpError(401, "UNAUTHORIZED", "Yêu cầu đăng nhập.");
  }
  return user.id;
}

/**
 * Schema xác thực dữ liệu đầu vào khi thêm cây
 */
const addPlantSchema = z.object({
  nickname: z.string().trim().min(1, "Tên cây (nickname) không được để trống."),
  species_id: z.string().trim().optional(),
  cover_image_key: z.string().trim().optional(),
  environment: z.enum(["indoor", "outdoor", "unknown"]).optional(),
  latitude: z.number().min(-90).max(90).nullish(),
  longitude: z.number().min(-180).max(180).nullish(),
  region_name: z.string().trim().max(200).nullish(),
}).refine((plant) => (plant.latitude == null) === (plant.longitude == null), {
  message: "Cần gửi cả latitude và longitude.",
});

/**
 * Schema xác thực dữ liệu đầu vào khi đổi nickname
 */
const updateNicknameSchema = z.object({
  nickname: z.string().trim().min(1, "Biệt danh mới không được để trống."),
});

/**
 * 1. addPlantController: Thêm một cây mới vào vườn của user (status 201).
 */
export async function addPlantController(
  req: Request,
  res: Response,
  db?: Database,
  config?: Config,
): Promise<void> {
  try {
    const ownerId = getUserId(req, res);
    const parsedBody = addPlantSchema.parse(req.body);

    const plant = await addPlantService(ownerId, parsedBody, db, config);
    res.status(201).json({
      success: true,
      data: plant,
      error: null,
      message: "Thêm cây vào vườn thành công.",
    });
  } catch (error) {
    handleControllerError(res, error, "Không thể thêm cây vào vườn.");
  }
}

/**
 * 2. getGardenController: Lấy danh sách cây của user đang đăng nhập (status 200).
 */
export async function getGardenController(
  req: Request,
  res: Response,
  db?: Database,
  config?: Config,
): Promise<void> {
  try {
    const ownerId = getUserId(req, res);
    const plants = await getGardenPlantsService(ownerId, db, config);

    res.status(200).json({
      success: true,
      data: plants,
      error: null,
      message: "OK",
    });
  } catch (error) {
    handleControllerError(res, error, "Lỗi khi lấy danh sách cây.");
  }
}

/**
 * 3. updateNicknameController: Cập nhật nickname cho cây (status 200).
 */
export async function updateNicknameController(
  req: Request,
  res: Response,
  db?: Database,
): Promise<void> {
  try {
    const ownerId = getUserId(req, res);
    const plantId = z.string().trim().min(1, "plantId không hợp lệ.").parse(req.params.id || req.params.plantId);
    const { nickname } = updateNicknameSchema.parse(req.body);

    const updated = await updateNicknameService(plantId, ownerId, nickname, db);
    res.status(200).json({
      success: true,
      data: updated,
      error: null,
      message: "Cập nhật tên cây thành công.",
    });
  } catch (error) {
    handleControllerError(res, error, "Lỗi khi cập nhật tên cây.");
  }
}

/**
 * 4. removePlantController: Xóa cây khỏi vườn (status 200).
 */
export async function removePlantController(
  req: Request,
  res: Response,
  db?: Database,
): Promise<void> {
  try {
    const ownerId = getUserId(req, res);
    const plantId = z.string().trim().min(1, "plantId không hợp lệ.").parse(req.params.id || req.params.plantId);

    const removed = await removePlantService(plantId, ownerId, db);
    res.status(200).json({
      success: true,
      data: removed,
      error: null,
      message: "Xóa cây khỏi vườn thành công.",
    });
  } catch (error) {
    handleControllerError(res, error, "Lỗi khi xóa cây.");
  }
}

/**
 * Hàm trợ giúp xử lý và phân loại lỗi HTTP chuẩn (400, 401, 404, 500)
 */
function handleControllerError(
  res: Response,
  error: unknown,
  fallbackMessage: string,
): void {
  if (error instanceof z.ZodError) {
    res.status(400).json({
      success: false,
      data: null,
      error: { code: "INVALID_INPUT" },
      message: error.issues[0]?.message || "Dữ liệu gửi lên không hợp lệ.",
    });
    return;
  }

  if (error instanceof HttpError) {
    res.status(error.status).json({
      success: false,
      data: null,
      error: { code: error.code },
      message: error.message,
    });
    return;
  }

  const message = error instanceof Error ? error.message : fallbackMessage;
  res.status(500).json({
    success: false,
    data: null,
    error: { code: "INTERNAL_ERROR" },
    message,
  });
}

/**
 * Factory gardenController đóng gói toàn bộ handler (bao gồm cả các hàm list/detail cũ và 4 hàm mới)
 */
export function gardenController(db: Database, config?: Config): {
  list: RequestHandler;
  detail: RequestHandler;
  addPlant: RequestHandler;
  getGarden: RequestHandler;
  updateNickname: RequestHandler;
  removePlant: RequestHandler;
} {
  const service = gardenService(db, config);
  return {
    async list(req, res) {
      const { offset, limit } = z
        .object({
          offset: z.coerce.number().int().min(0).max(100000).default(0),
          limit: z.coerce.number().int().min(1).max(100).default(20),
        })
        .parse(req.query);
      success(res, await service.list(res.locals.user.id, offset, limit));
    },
    async detail(req, res) {
      success(
        res,
        await service.detail(res.locals.user.id, z.uuid().parse(req.params.id)),
      );
    },
    addPlant(req, res) {
      return addPlantController(req, res, db, config);
    },
    getGarden(req, res) {
      return getGardenController(req, res, db, config);
    },
    updateNickname(req, res) {
      return updateNicknameController(req, res, db);
    },
    removePlant(req, res) {
      return removePlantController(req, res, db);
    },
  };
}
