import { randomUUID } from "node:crypto";
import { Prisma } from "../generated/prisma/client.js";
import type { care_logsModel } from "../generated/prisma/models/care_logs.js";
import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";

export type CareLog = care_logsModel;

export const CARE_LOG_KINDS = ["water", "fertilize", "treat", "note"] as const;
export type CareLogKind = (typeof CARE_LOG_KINDS)[number];

export interface CreateCareLogInput {
  kind: string;
  note?: string | null;
  performed_at?: string | Date | null;
  request_id?: string | null;
  task_id?: string | null;
}

export interface ListCareLogsQuery {
  kind?: string | null;
  limit?: number | null;
}

export interface UpdateCareLogInput {
  kind?: string | null;
  note?: string | null;
  performed_at?: string | Date | null;
}

/**
 * 1. createCareLog: Tạo nhật ký chăm sóc cây mới.
 * - Kiểm tra cây (plantId) tồn tại và thuộc về ownerId.
 * - Hỗ trợ idempotent: nếu có cặp (plant_id, request_id) thì trả về luôn bản ghi đó.
 * - Nếu có task_id: kiểm tra task thuộc plant_id, khớp kind, và cập nhật task sang "done".
 */
export async function createCareLog(
  db: Database,
  ownerId: string,
  plantId: string,
  data: CreateCareLogInput,
): Promise<CareLog> {
  if (!ownerId || !ownerId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "ownerId không được để trống.");
  }
  if (!plantId || !plantId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "plantId không được để trống.");
  }
  if (!data || !data.kind || !data.kind.trim()) {
    throw new HttpError(
      400,
      "INVALID_INPUT",
      "Loại chăm sóc (kind) không được để trống.",
    );
  }

  const kind = data.kind.trim();
  if (!CARE_LOG_KINDS.includes(kind as CareLogKind)) {
    throw new HttpError(
      400,
      "INVALID_INPUT",
      `Loại chăm sóc '${kind}' không hợp lệ. Cho phép: ${CARE_LOG_KINDS.join(", ")}.`,
    );
  }

  const requestId = data.request_id?.trim() || randomUUID();

  // Kiểm tra cây có tồn tại và thuộc về ownerId không
  const plant = await db.plants.findFirst({
    where: {
      id: plantId.trim(),
      owner_id: ownerId.trim(),
    },
  });
  if (!plant) {
    throw new HttpError(
      404,
      "NOT_FOUND",
      "Không tìm thấy cây hoặc bạn không có quyền truy cập.",
    );
  }

  // Kiểm tra idempotency theo cặp (plant_id, request_id)
  const existingLog = await db.care_logs.findUnique({
    where: {
      plant_id_request_id: {
        plant_id: plantId.trim(),
        request_id: requestId,
      },
    },
  });
  if (existingLog) {
    return existingLog;
  }

  // Nếu có task_id, kiểm tra tính hợp lệ của nhiệm vụ
  if (data.task_id) {
    const task = await db.care_tasks.findUnique({
      where: { id: data.task_id.trim() },
    });
    if (!task || task.plant_id !== plantId.trim()) {
      throw new HttpError(
        404,
        "NOT_FOUND",
        "Không tìm thấy nhiệm vụ chăm sóc cho cây này.",
      );
    }
    if (task.kind !== kind) {
      throw new HttpError(
        400,
        "INVALID_INPUT",
        `Loại chăm sóc không khớp với nhiệm vụ (nhiệm vụ: ${task.kind}, nhật ký: ${kind}).`,
      );
    }

    const logWithTask = await db.care_logs.findUnique({
      where: { task_id: data.task_id.trim() },
    });
    if (logWithTask) {
      throw new HttpError(
        409,
        "CONFLICT",
        "Nhiệm vụ này đã được hoàn thành và ghi nhận trong nhật ký trước đó.",
      );
    }
  }

  const performedAt = data.performed_at
    ? new Date(data.performed_at)
    : new Date();
  if (isNaN(performedAt.getTime())) {
    throw new HttpError(
      400,
      "INVALID_INPUT",
      "Thời gian thực hiện (performed_at) không hợp lệ.",
    );
  }

  try {
    return await db.$transaction(async (tx) => {
      const log = await tx.care_logs.create({
        data: {
          plant_id: plantId.trim(),
          request_id: requestId,
          task_id: data.task_id?.trim() || null,
          kind,
          performed_at: performedAt,
          note: data.note?.trim() || null,
        },
      });

      if (data.task_id) {
        await tx.care_tasks.update({
          where: { id: data.task_id.trim() },
          data: { state: "done" },
        });
      }

      return log;
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      // Xử lý race condition idempotency nếu 2 request gửi cùng lúc
      if (error.code === "P2002") {
        const raceLog = await db.care_logs.findUnique({
          where: {
            plant_id_request_id: {
              plant_id: plantId.trim(),
              request_id: requestId,
            },
          },
        });
        if (raceLog) return raceLog;
      }
      if (error.code === "P2003") {
        throw new HttpError(
          400,
          "INVALID_REFERENCE",
          "Thông tin tham chiếu cây hoặc nhiệm vụ không hợp lệ.",
        );
      }
    }
    throw new HttpError(
      500,
      "CREATE_CARE_LOG_FAILED",
      `Không thể tạo nhật ký chăm sóc: ${error instanceof Error ? error.message : "Lỗi không xác định"}`,
    );
  }
}

/**
 * 2. listCareLogsByPlant: Lấy danh sách lịch sử chăm sóc của một cây.
 * - Kiểm tra quyền sở hữu cây của ownerId.
 * - Hỗ trợ lọc theo kind và giới hạn limit.
 * - Sắp xếp theo performed_at giảm dần (mới nhất lên đầu).
 */
export async function listCareLogsByPlant(
  db: Database,
  ownerId: string,
  plantId: string,
  query?: ListCareLogsQuery,
): Promise<CareLog[]> {
  if (!ownerId || !ownerId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "ownerId không được để trống.");
  }
  if (!plantId || !plantId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "plantId không được để trống.");
  }

  // Kiểm tra quyền sở hữu cây
  const plant = await db.plants.findFirst({
    where: {
      id: plantId.trim(),
      owner_id: ownerId.trim(),
    },
  });
  if (!plant) {
    throw new HttpError(
      404,
      "NOT_FOUND",
      "Không tìm thấy cây hoặc bạn không có quyền truy cập.",
    );
  }

  const where: Prisma.care_logsWhereInput = {
    plant_id: plantId.trim(),
  };

  if (query?.kind && query.kind.trim()) {
    where.kind = query.kind.trim();
  }

  try {
    return await db.care_logs.findMany({
      where,
      orderBy: [{ performed_at: "desc" }, { id: "desc" }],
      ...(query?.limit && query.limit > 0 ? { take: query.limit } : {}),
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(
      500,
      "FETCH_CARE_LOGS_FAILED",
      `Lỗi khi lấy danh sách nhật ký chăm sóc: ${error instanceof Error ? error.message : "Lỗi không xác định"}`,
    );
  }
}

/**
 * 3. updateCareLog: Cập nhật thông tin nhật ký chăm sóc.
 * - Tìm care_log theo logId kèm quan hệ plants để kiểm tra plants.owner_id === ownerId.
 * - Cập nhật thông tin ghi chú/loại chăm sóc/thời gian.
 */
export async function updateCareLog(
  db: Database,
  ownerId: string,
  logId: string,
  data: UpdateCareLogInput,
): Promise<CareLog> {
  if (!ownerId || !ownerId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "ownerId không được để trống.");
  }
  if (!logId || !logId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "logId không được để trống.");
  }

  // Tìm care_log kèm quan hệ plants để kiểm tra quyền sở hữu
  const existing = await db.care_logs.findUnique({
    where: { id: logId.trim() },
    include: {
      plants: {
        select: {
          id: true,
          owner_id: true,
        },
      },
    },
  });

  if (!existing || existing.plants.owner_id !== ownerId.trim()) {
    throw new HttpError(
      404,
      "NOT_FOUND",
      "Không tìm thấy nhật ký chăm sóc hoặc bạn không có quyền chỉnh sửa.",
    );
  }

  const updateData: Prisma.care_logsUncheckedUpdateInput = {};

  if (data.kind !== undefined && data.kind !== null) {
    const kind = data.kind.trim();
    if (!CARE_LOG_KINDS.includes(kind as CareLogKind)) {
      throw new HttpError(
        400,
        "INVALID_INPUT",
        `Loại chăm sóc '${kind}' không hợp lệ. Cho phép: ${CARE_LOG_KINDS.join(", ")}.`,
      );
    }
    // Nếu nhật ký này đang liên kết với 1 task, không cho phép đổi kind khác với task
    if (existing.task_id && kind !== existing.kind) {
      throw new HttpError(
        400,
        "INVALID_INPUT",
        "Không thể thay đổi loại chăm sóc (kind) của nhật ký đã liên kết với nhiệm vụ lịch trình.",
      );
    }
    updateData.kind = kind;
  }

  if (data.note !== undefined) {
    updateData.note = data.note ? data.note.trim() : null;
  }

  if (data.performed_at !== undefined && data.performed_at !== null) {
    const performedAt = new Date(data.performed_at);
    if (isNaN(performedAt.getTime())) {
      throw new HttpError(
        400,
        "INVALID_INPUT",
        "Thời gian thực hiện (performed_at) không hợp lệ.",
      );
    }
    updateData.performed_at = performedAt;
  }

  try {
    return await db.care_logs.update({
      where: { id: logId.trim() },
      data: updateData,
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(
      500,
      "UPDATE_CARE_LOG_FAILED",
      `Không thể cập nhật nhật ký chăm sóc: ${error instanceof Error ? error.message : "Lỗi không xác định"}`,
    );
  }
}

/**
 * 4. deleteCareLog: Xóa nhật ký chăm sóc khỏi database.
 * - Kiểm tra care_log thuộc cây của ownerId rồi xóa.
 * - Nếu nhật ký gắn với task, hoàn tác trạng thái task về "pending".
 */
export async function deleteCareLog(
  db: Database,
  ownerId: string,
  logId: string,
): Promise<CareLog> {
  if (!ownerId || !ownerId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "ownerId không được để trống.");
  }
  if (!logId || !logId.trim()) {
    throw new HttpError(400, "INVALID_INPUT", "logId không được để trống.");
  }

  // Tìm care_log kèm quan hệ plants để kiểm tra quyền sở hữu
  const existing = await db.care_logs.findUnique({
    where: { id: logId.trim() },
    include: {
      plants: {
        select: {
          id: true,
          owner_id: true,
        },
      },
    },
  });

  if (!existing || existing.plants.owner_id !== ownerId.trim()) {
    throw new HttpError(
      404,
      "NOT_FOUND",
      "Không tìm thấy nhật ký chăm sóc hoặc bạn không có quyền xóa.",
    );
  }

  try {
    return await db.$transaction(async (tx) => {
      // Nếu có gắn với task, cập nhật lại trạng thái pending
      if (existing.task_id) {
        await tx.care_tasks.updateMany({
          where: { id: existing.task_id, state: "done" },
          data: { state: "pending" },
        });
      }

      return await tx.care_logs.delete({
        where: { id: logId.trim() },
      });
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(
      500,
      "DELETE_CARE_LOG_FAILED",
      `Không thể xóa nhật ký chăm sóc: ${error instanceof Error ? error.message : "Lỗi không xác định"}`,
    );
  }
}

/**
 * Factory careLogService đóng gói các thao tác theo pattern service trong dự án
 */
export function careLogService(db: Database) {
  return {
    create(ownerId: string, plantId: string, data: CreateCareLogInput) {
      return createCareLog(db, ownerId, plantId, data);
    },
    listByPlant(ownerId: string, plantId: string, query?: ListCareLogsQuery) {
      return listCareLogsByPlant(db, ownerId, plantId, query);
    },
    update(ownerId: string, logId: string, data: UpdateCareLogInput) {
      return updateCareLog(db, ownerId, logId, data);
    },
    delete(ownerId: string, logId: string) {
      return deleteCareLog(db, ownerId, logId);
    },
  };
}
