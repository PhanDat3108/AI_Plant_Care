import { Prisma } from "../generated/prisma/client.js";
import type { plantsModel } from "../generated/prisma/models/plants.js";
import { createDatabase, type Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";

export type Plant = plantsModel;

export interface AddPlantInput {
  nickname: string;
  species_id?: string;
  cover_image_key?: string;
  environment?: string;
}

let defaultDb: Database | undefined;

function getDatabase(client?: Database): Database {
  if (client) return client;
  if (!defaultDb) {
    const url = process.env.DATABASE_URL;
    if (!url) {
      throw new HttpError(
        500,
        "CONFIG_ERROR",
        "DATABASE_URL chưa được cấu hình.",
      );
    }
    defaultDb = createDatabase(url);
  }
  return defaultDb;
}

/**
 * 1. Thêm một cây mới vào vườn của user.
 */
export async function addPlant(
  ownerId: string,
  data: AddPlantInput,
  client?: Database,
): Promise<Plant> {
  if (!ownerId || !ownerId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "ownerId không được để trống.");
  }
  if (!data || typeof data.nickname !== "string" || !data.nickname.trim()) {
    throw new HttpError(
      400,
      "INVALID_INPUT",
      "Tên cây (nickname) không được để trống.",
    );
  }

  const validEnvironments = ["indoor", "outdoor", "unknown"];
  if (data.environment && !validEnvironments.includes(data.environment)) {
    throw new HttpError(
      400,
      "INVALID_INPUT",
      "Môi trường (environment) phải là 'indoor', 'outdoor' hoặc 'unknown'.",
    );
  }

  const db = getDatabase(client);

  try {
    return await db.plants.create({
      data: {
        owner_id: ownerId.trim(),
        nickname: data.nickname.trim(),
        species_id: data.species_id?.trim() || null,
        cover_image_key: data.cover_image_key?.trim() || null,
        environment: data.environment ?? "unknown",
      },
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      if (error.code === "P2003") {
        throw new HttpError(
          400,
          "INVALID_REFERENCE",
          "Thông tin chủ sở hữu (owner_id) hoặc loài cây (species_id) không tồn tại.",
        );
      }
    }
    throw new HttpError(
      500,
      "CREATE_PLANT_FAILED",
      `Không thể thêm cây vào vườn: ${error instanceof Error ? error.message : "Lỗi không xác định"}`,
    );
  }
}

/**
 * 2. Lấy danh sách tất cả các cây thuộc về ownerId này (sắp xếp theo created_at giảm dần).
 */
export async function getGardenPlants(
  ownerId: string,
  client?: Database,
): Promise<Plant[]> {
  if (!ownerId || !ownerId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "ownerId không được để trống.");
  }

  const db = getDatabase(client);

  try {
    return await db.plants.findMany({
      where: { owner_id: ownerId.trim() },
      orderBy: [{ created_at: "desc" }, { id: "desc" }],
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(
      500,
      "FETCH_PLANTS_FAILED",
      `Lỗi khi lấy danh sách cây: ${error instanceof Error ? error.message : "Lỗi không xác định"}`,
    );
  }
}

/**
 * 3. Cập nhật trường nickname cho cây (kiểm tra đúng id và owner_id để bảo mật).
 */
export async function updatePlantNickname(
  plantId: string,
  ownerId: string,
  newNickname: string,
  client?: Database,
): Promise<Plant> {
  if (!plantId || !plantId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "plantId không được để trống.");
  }
  if (!ownerId || !ownerId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "ownerId không được để trống.");
  }
  if (!newNickname || !newNickname.trim()) {
    throw new HttpError(
      400,
      "INVALID_INPUT",
      "Biệt danh mới (newNickname) không được để trống.",
    );
  }

  const db = getDatabase(client);

  try {
    // Kiểm tra quyền sở hữu trước khi cập nhật
    const existing = await db.plants.findFirst({
      where: {
        id: plantId.trim(),
        owner_id: ownerId.trim(),
      },
    });

    if (!existing) {
      throw new HttpError(
        404,
        "NOT_FOUND",
        "Không tìm thấy cây hoặc bạn không có quyền cập nhật cây này.",
      );
    }

    return await db.plants.update({
      where: { id: plantId.trim() },
      data: {
        nickname: newNickname.trim(),
      },
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(
      500,
      "UPDATE_PLANT_FAILED",
      `Không thể cập nhật tên cây: ${error instanceof Error ? error.message : "Lỗi không xác định"}`,
    );
  }
}

/**
 * 4. Xóa cây khỏi database (kiểm tra đúng id và owner_id để bảo mật).
 */
export async function removePlant(
  plantId: string,
  ownerId: string,
  client?: Database,
): Promise<Plant> {
  if (!plantId || !plantId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "plantId không được để trống.");
  }
  if (!ownerId || !ownerId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "ownerId không được để trống.");
  }

  const db = getDatabase(client);

  try {
    // Kiểm tra quyền sở hữu trước khi xóa
    const existing = await db.plants.findFirst({
      where: {
        id: plantId.trim(),
        owner_id: ownerId.trim(),
      },
    });

    if (!existing) {
      throw new HttpError(
        404,
        "NOT_FOUND",
        "Không tìm thấy cây hoặc bạn không có quyền xóa cây này.",
      );
    }

    return await db.plants.delete({
      where: { id: plantId.trim() },
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(
      500,
      "DELETE_PLANT_FAILED",
      `Không thể xóa cây khỏi database: ${error instanceof Error ? error.message : "Lỗi không xác định"}`,
    );
  }
}

export function gardenService(db: Database) {
  return {
    list(ownerId: string, skip: number, take: number) {
      return db.plants.findMany({
        where: { owner_id: ownerId },
        skip,
        take,
        orderBy: [{ created_at: "desc" }, { id: "desc" }],
      });
    },
    async detail(ownerId: string, id: string) {
      const plant = await db.plants.findFirst({
        where: { id, owner_id: ownerId },
      });
      if (!plant) throw new HttpError(404, "NOT_FOUND", "Không tìm thấy cây.");
      const species = plant.species_id
        ? await db.plant_species.findUnique({ where: { id: plant.species_id } })
        : null;
      const referenceImage = plant.reference_image_id
        ? await db.reference_images.findUnique({
            where: { id: plant.reference_image_id },
          })
        : null;
      return { ...plant, species, referenceImage };
    },
    addPlant(ownerId: string, data: AddPlantInput) {
      return addPlant(ownerId, data, db);
    },
    getGardenPlants(ownerId: string) {
      return getGardenPlants(ownerId, db);
    },
    updatePlantNickname(plantId: string, ownerId: string, newNickname: string) {
      return updatePlantNickname(plantId, ownerId, newNickname, db);
    },
    removePlant(plantId: string, ownerId: string) {
      return removePlant(plantId, ownerId, db);
    },
  };
}
