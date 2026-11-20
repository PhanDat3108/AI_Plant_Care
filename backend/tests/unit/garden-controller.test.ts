import { describe, expect, it, vi, beforeEach } from "vitest";
import type { Request, Response } from "express";
import {
  addPlantController,
  getGardenController,
  updateNicknameController,
  removePlantController,
} from "../../src/controllers/garden.js";
import * as gardenServiceModule from "../../src/services/garden.js";
import { HttpError } from "../../src/middlewares/errors.js";

describe("Garden Controllers", () => {
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;
  let jsonMock: ReturnType<typeof vi.fn>;
  let statusMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.clearAllMocks();
    jsonMock = vi.fn();
    statusMock = vi.fn().mockReturnValue({ json: jsonMock });
    mockRes = {
      status: statusMock as unknown as Response["status"],
      json: jsonMock as unknown as Response["json"],
      locals: {
        user: { id: "user-123", displayName: "Tester", isDemo: false },
      },
    };
  });

  describe("addPlantController", () => {
    it("thêm cây thành công trả về 201", async () => {
      mockReq = {
        body: {
          nickname: "Cây Kim Ngân",
          environment: "indoor",
        },
      };

      const mockCreated = {
        id: "plant-1",
        owner_id: "user-123",
        nickname: "Cây Kim Ngân",
        environment: "indoor",
      } as unknown as gardenServiceModule.Plant;

      vi.spyOn(gardenServiceModule, "addPlant").mockResolvedValue(mockCreated);

      await addPlantController(mockReq as Request, mockRes as Response);

      expect(statusMock).toHaveBeenCalledWith(201);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: mockCreated,
        }),
      );
    });

    it.each([{ latitude: 10 }, { longitude: 106 }, { latitude: 91, longitude: 106 }])(
      "từ chối tọa độ không hợp lệ %o", async (location) => {
        mockReq = { body: { nickname: "Sen", ...location } };
        await addPlantController(mockReq as Request, mockRes as Response);
        expect(statusMock).toHaveBeenCalledWith(400);
      },
    );

    it("trả về 400 nếu dữ liệu body không hợp lệ (nickname rỗng)", async () => {
      mockReq = {
        body: {
          nickname: "   ",
        },
      };

      await addPlantController(mockReq as Request, mockRes as Response);

      expect(statusMock).toHaveBeenCalledWith(400);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: false,
          error: { code: "INVALID_INPUT" },
        }),
      );
    });
  });

  describe("getGardenController", () => {
    it("lấy danh sách cây thành công trả về 200", async () => {
      mockReq = {};
      const mockList = [
        { id: "plant-1", owner_id: "user-123", nickname: "Cây 1" },
      ] as unknown as gardenServiceModule.Plant[];

      vi.spyOn(gardenServiceModule, "getGardenPlants").mockResolvedValue(mockList);

      await getGardenController(mockReq as Request, mockRes as Response);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: mockList,
        }),
      );
    });
  });

  describe("updateNicknameController", () => {
    it("cập nhật nickname thành công trả về 200", async () => {
      mockReq = {
        params: { id: "plant-123" },
        body: { nickname: "Tên Mới" },
      };

      const updated = {
        id: "plant-123",
        owner_id: "user-123",
        nickname: "Tên Mới",
      } as unknown as gardenServiceModule.Plant;

      vi.spyOn(gardenServiceModule, "updatePlantNickname").mockResolvedValue(updated);

      await updateNicknameController(mockReq as Request, mockRes as Response);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: updated,
        }),
      );
    });

    it("trả về 404 khi không tìm thấy hoặc không có quyền", async () => {
      mockReq = {
        params: { id: "plant-not-found" },
        body: { nickname: "Tên Mới" },
      };

      vi.spyOn(gardenServiceModule, "updatePlantNickname").mockRejectedValue(
        new HttpError(404, "NOT_FOUND", "Không tìm thấy cây"),
      );

      await updateNicknameController(mockReq as Request, mockRes as Response);

      expect(statusMock).toHaveBeenCalledWith(404);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: false,
          error: { code: "NOT_FOUND" },
        }),
      );
    });
  });

  describe("removePlantController", () => {
    it("xóa cây thành công trả về 200", async () => {
      mockReq = {
        params: { id: "plant-123" },
      };

      const removed = {
        id: "plant-123",
        owner_id: "user-123",
      } as unknown as gardenServiceModule.Plant;

      vi.spyOn(gardenServiceModule, "removePlant").mockResolvedValue(removed);

      await removePlantController(mockReq as Request, mockRes as Response);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: removed,
        }),
      );
    });
  });
});
