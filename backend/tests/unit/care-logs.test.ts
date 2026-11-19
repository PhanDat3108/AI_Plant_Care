import { describe, expect, it, vi, beforeEach } from "vitest";
import {
  createCareLog,
  listCareLogsByPlant,
  updateCareLog,
  deleteCareLog,
  type CareLog,
} from "../../src/services/care-logs.js";
import { HttpError } from "../../src/middlewares/errors.js";
import type { Database } from "../../src/config/database.js";
import type { plantsModel } from "../../src/generated/prisma/models/plants.js";
import type { care_tasksModel } from "../../src/generated/prisma/models/care_tasks.js";

describe("Care Logs Service Functions", () => {
  const mockDb = {
    plants: {
      findFirst: vi.fn(),
    },
    care_logs: {
      create: vi.fn(),
      findUnique: vi.fn(),
      findMany: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
    care_tasks: {
      findUnique: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
    },
    $transaction: vi.fn(async (callback: (tx: typeof mockDb) => Promise<unknown>) =>
      callback(mockDb),
    ),
  } as unknown as Database;

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("createCareLog", () => {
    it("tạo nhật ký chăm sóc thành công không kèm task_id", async () => {
      const mockPlant = { id: "plant-1", owner_id: "user-1" };
      const mockCreatedLog = {
        id: "log-1",
        plant_id: "plant-1",
        request_id: "req-1",
        task_id: null,
        kind: "water",
        performed_at: new Date(),
        note: "Tưới 200ml",
      } as unknown as CareLog;

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(null);
      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
        mockPlant as unknown as plantsModel,
      );
      vi.mocked(mockDb.care_logs.create).mockResolvedValue(mockCreatedLog);

      const result = await createCareLog(mockDb, "user-1", "plant-1", {
        kind: "water",
        note: "Tưới 200ml",
        request_id: "req-1",
      });

      expect(mockDb.care_logs.findUnique).toHaveBeenCalledWith({
        where: {
          plant_id_request_id: {
            plant_id: "plant-1",
            request_id: "req-1",
          },
        },
      });
      expect(mockDb.plants.findFirst).toHaveBeenCalledWith({
        where: { id: "plant-1", owner_id: "user-1" },
      });
      expect(mockDb.care_logs.create).toHaveBeenCalled();
      expect(result).toEqual(mockCreatedLog);
    });

    it("idempotent: trả về bản ghi cũ nếu cặp (plant_id, request_id) đã tồn tại", async () => {
      const existing = {
        id: "log-existing",
        plant_id: "plant-1",
        request_id: "req-1",
        kind: "water",
      } as unknown as CareLog;

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(existing);

      const result = await createCareLog(mockDb, "user-1", "plant-1", {
        kind: "water",
        request_id: "req-1",
      });

      expect(result).toEqual(existing);
      expect(mockDb.care_logs.create).not.toHaveBeenCalled();
    });

    it("báo lỗi 404 nếu không tìm thấy cây hoặc không thuộc owner", async () => {
      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(null);
      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(null);

      await expect(
        createCareLog(mockDb, "user-1", "plant-other", {
          kind: "water",
        }),
      ).rejects.toThrow(HttpError);
    });

    it("khi có task_id hợp lệ: tạo log và cập nhật task sang done", async () => {
      const mockPlant = { id: "plant-1", owner_id: "user-1" };
      const mockTask = {
        id: "task-1",
        plant_id: "plant-1",
        kind: "fertilize",
        state: "pending",
      };
      const mockCreatedLog = {
        id: "log-2",
        plant_id: "plant-1",
        task_id: "task-1",
        kind: "fertilize",
      } as unknown as CareLog;

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(null);
      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
        mockPlant as unknown as plantsModel,
      );
      vi.mocked(mockDb.care_tasks.findUnique).mockResolvedValue(
        mockTask as unknown as care_tasksModel,
      );
      vi.mocked(mockDb.care_logs.create).mockResolvedValue(mockCreatedLog);

      const result = await createCareLog(mockDb, "user-1", "plant-1", {
        kind: "fertilize",
        task_id: "task-1",
      });

      expect(mockDb.care_tasks.findUnique).toHaveBeenCalledWith({
        where: { id: "task-1" },
      });
      expect(mockDb.care_tasks.update).toHaveBeenCalledWith({
        where: { id: "task-1" },
        data: { state: "done" },
      });
      expect(result).toEqual(mockCreatedLog);
    });

    it("báo lỗi 400 nếu kind của task không khớp với data.kind", async () => {
      const mockPlant = { id: "plant-1", owner_id: "user-1" };
      const mockTask = {
        id: "task-1",
        plant_id: "plant-1",
        kind: "water",
      };

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(null);
      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
        mockPlant as unknown as plantsModel,
      );
      vi.mocked(mockDb.care_tasks.findUnique).mockResolvedValue(
        mockTask as unknown as care_tasksModel,
      );

      await expect(
        createCareLog(mockDb, "user-1", "plant-1", {
          kind: "fertilize",
          task_id: "task-1",
        }),
      ).rejects.toThrow(HttpError);
    });

    it("báo lỗi 409 nếu task_id này đã được ghi log trước đó", async () => {
      const mockPlant = { id: "plant-1", owner_id: "user-1" };
      const mockTask = {
        id: "task-1",
        plant_id: "plant-1",
        kind: "water",
      };

      vi.mocked(mockDb.care_logs.findUnique)
        .mockResolvedValueOnce(null) // plant_id_request_id check
        .mockResolvedValueOnce({ id: "log-old" } as unknown as CareLog); // task_id check
      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
        mockPlant as unknown as plantsModel,
      );
      vi.mocked(mockDb.care_tasks.findUnique).mockResolvedValue(
        mockTask as unknown as care_tasksModel,
      );

      await expect(
        createCareLog(mockDb, "user-1", "plant-1", {
          kind: "water",
          task_id: "task-1",
        }),
      ).rejects.toThrow(HttpError);
    });

    it("báo lỗi 400 nếu kind không hợp lệ", async () => {
      await expect(
        createCareLog(mockDb, "user-1", "plant-1", {
          kind: "fly",
        }),
      ).rejects.toThrow(HttpError);
    });
  });

  describe("listCareLogsByPlant", () => {
    it("lấy danh sách nhật ký theo thứ tự performed_at giảm dần", async () => {
      const mockPlant = { id: "plant-1", owner_id: "user-1" };
      const mockLogs = [
        { id: "log-2", plant_id: "plant-1", performed_at: new Date(2026, 1, 2) },
        { id: "log-1", plant_id: "plant-1", performed_at: new Date(2026, 1, 1) },
      ] as unknown as CareLog[];

      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
        mockPlant as unknown as plantsModel,
      );
      vi.mocked(mockDb.care_logs.findMany).mockResolvedValue(mockLogs);

      const result = await listCareLogsByPlant(mockDb, "user-1", "plant-1", {
        kind: "water",
        limit: 10,
      });

      expect(mockDb.care_logs.findMany).toHaveBeenCalledWith({
        where: { plant_id: "plant-1", kind: "water" },
        orderBy: [{ performed_at: "desc" }, { id: "desc" }],
        take: 10,
      });
      expect(result).toEqual(mockLogs);
    });

    it("báo lỗi 404 khi người dùng không sở hữu cây", async () => {
      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(null);

      await expect(
        listCareLogsByPlant(mockDb, "user-other", "plant-1"),
      ).rejects.toThrow(HttpError);
    });
  });

  describe("updateCareLog", () => {
    it("cập nhật nhật ký thành công khi thuộc về user", async () => {
      const existing = {
        id: "log-1",
        kind: "water",
        task_id: null,
        plants: { id: "plant-1", owner_id: "user-1" },
      };
      const updated = {
        ...existing,
        note: "Ghi chú mới",
      } as unknown as CareLog;

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(
        existing as unknown as CareLog,
      );
      vi.mocked(mockDb.care_logs.update).mockResolvedValue(updated);

      const result = await updateCareLog(mockDb, "user-1", "log-1", {
        note: "Ghi chú mới",
      });

      expect(mockDb.care_logs.update).toHaveBeenCalledWith({
        where: { id: "log-1" },
        data: { note: "Ghi chú mới" },
      });
      expect(result).toEqual(updated);
    });

    it("báo lỗi 404 nếu nhật ký không thuộc user", async () => {
      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(null);

      await expect(
        updateCareLog(mockDb, "user-1", "log-other", { note: "Test" }),
      ).rejects.toThrow(HttpError);
    });

    it("báo lỗi 400 nếu đổi kind khi nhật ký đã gắn với task_id", async () => {
      const existing = {
        id: "log-1",
        kind: "water",
        task_id: "task-1",
        plants: { id: "plant-1", owner_id: "user-1" },
      };

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(
        existing as unknown as CareLog,
      );

      await expect(
        updateCareLog(mockDb, "user-1", "log-1", { kind: "fertilize" }),
      ).rejects.toThrow(HttpError);
    });
  });

  describe("deleteCareLog", () => {
    it("xóa nhật ký thành công và hoàn tác trạng thái task về pending nếu có task_id", async () => {
      const existing = {
        id: "log-1",
        task_id: "task-1",
        plants: { id: "plant-1", owner_id: "user-1" },
      };

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(
        existing as unknown as CareLog,
      );
      vi.mocked(mockDb.care_logs.delete).mockResolvedValue(
        existing as unknown as CareLog,
      );

      const result = await deleteCareLog(mockDb, "user-1", "log-1");

      expect(mockDb.care_tasks.updateMany).toHaveBeenCalledWith({
        where: { id: "task-1", state: "done" },
        data: { state: "pending" },
      });
      expect(mockDb.care_logs.delete).toHaveBeenCalledWith({
        where: { id: "log-1" },
      });
      expect(result).toEqual(existing);
    });

    it("báo lỗi 404 nếu không tìm thấy log hoặc không thuộc owner", async () => {
      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(null);

      await expect(deleteCareLog(mockDb, "user-1", "log-1")).rejects.toThrow(
        HttpError,
      );
    });
  });
});
