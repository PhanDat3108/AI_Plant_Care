import { describe, expect, it, vi, beforeEach } from "vitest";
import type { Request, Response, NextFunction } from "express";
import { careLogsController } from "../../src/controllers/care-logs.js";
import type { Database } from "../../src/config/database.js";
import type { CareLog } from "../../src/services/care-logs.js";
import type { plantsModel } from "../../src/generated/prisma/models/plants.js";

describe("careLogsController", () => {
  let mockDb: Database;
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;
  let mockNext: NextFunction;
  let statusMock: ReturnType<typeof vi.fn>;
  let jsonMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.clearAllMocks();
    jsonMock = vi.fn();
    statusMock = vi.fn().mockReturnValue({ json: jsonMock });
    mockNext = vi.fn();

    mockDb = {
      care_logs: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
      plants: {
        findFirst: vi.fn(),
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

    mockRes = {
      status: statusMock as unknown as Response["status"],
      json: jsonMock as unknown as Response["json"],
      locals: {
        user: { id: "user-123" },
      },
    };
  });

  describe("create", () => {
    it("tạo nhật ký thành công trả về 201", async () => {
      mockReq = {
        params: { id: "plant-1" },
        body: { kind: "water", note: "Đã tưới nước" },
      };

      const mockPlant = { id: "plant-1", owner_id: "user-123" };
      const mockCreated = {
        id: "log-1",
        plant_id: "plant-1",
        kind: "water",
        note: "Đã tưới nước",
      } as unknown as CareLog;

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(null);
      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
        mockPlant as unknown as plantsModel,
      );
      vi.mocked(mockDb.care_logs.create).mockResolvedValue(mockCreated);

      const controller = careLogsController(mockDb);
      await controller.create(
        mockReq as Request,
        mockRes as Response,
        mockNext,
      );

      expect(statusMock).toHaveBeenCalledWith(201);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: mockCreated,
        }),
      );
      expect(mockNext).not.toHaveBeenCalled();
    });

    it("gọi next với lỗi validation nếu thiếu kind", async () => {
      mockReq = {
        params: { id: "plant-1" },
        body: { note: "Thiếu kind" },
      };

      const controller = careLogsController(mockDb);
      await controller.create(
        mockReq as Request,
        mockRes as Response,
        mockNext,
      );

      expect(mockNext).toHaveBeenCalledWith(expect.any(Error));
    });
  });

  describe("list", () => {
    it("lấy danh sách nhật ký trả về 200", async () => {
      mockReq = {
        params: { id: "plant-1" },
        query: { kind: "water" },
      };

      const mockPlant = { id: "plant-1", owner_id: "user-123" };
      const mockLogs = [
        { id: "log-1", kind: "water" },
      ] as unknown as CareLog[];

      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
        mockPlant as unknown as plantsModel,
      );
      vi.mocked(mockDb.care_logs.findMany).mockResolvedValue(mockLogs);

      const controller = careLogsController(mockDb);
      await controller.list(mockReq as Request, mockRes as Response, mockNext);

      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: mockLogs,
        }),
      );
      expect(mockNext).not.toHaveBeenCalled();
    });
  });

  describe("update", () => {
    it("cập nhật nhật ký trả về 200", async () => {
      mockReq = {
        params: { logId: "log-1" },
        body: { note: "Cập nhật ghi chú" },
      };

      const existing = {
        id: "log-1",
        task_id: null,
        plants: { id: "plant-1", owner_id: "user-123" },
      };
      const updatedLog = {
        id: "log-1",
        note: "Cập nhật ghi chú",
      } as unknown as CareLog;

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(
        existing as unknown as CareLog,
      );
      vi.mocked(mockDb.care_logs.update).mockResolvedValue(updatedLog);

      const controller = careLogsController(mockDb);
      await controller.update(
        mockReq as Request,
        mockRes as Response,
        mockNext,
      );

      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: updatedLog,
        }),
      );
      expect(mockNext).not.toHaveBeenCalled();
    });

    it("gọi next khi log không tồn tại hoặc không thuộc user", async () => {
      mockReq = {
        params: { logId: "log-unknown" },
        body: { note: "Test" },
      };

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(null);

      const controller = careLogsController(mockDb);
      await controller.update(
        mockReq as Request,
        mockRes as Response,
        mockNext,
      );

      expect(mockNext).toHaveBeenCalledWith(expect.any(Error));
    });
  });

  describe("remove", () => {
    it("xóa nhật ký trả về 200", async () => {
      mockReq = {
        params: { logId: "log-1" },
      };

      const existing = {
        id: "log-1",
        task_id: null,
        plants: { id: "plant-1", owner_id: "user-123" },
      };
      const deletedLog = { id: "log-1" } as unknown as CareLog;

      vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(
        existing as unknown as CareLog,
      );
      vi.mocked(mockDb.care_logs.delete).mockResolvedValue(deletedLog);

      const controller = careLogsController(mockDb);
      await controller.remove(
        mockReq as Request,
        mockRes as Response,
        mockNext,
      );

      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: deletedLog,
        }),
      );
      expect(mockNext).not.toHaveBeenCalled();
    });
  });
});
