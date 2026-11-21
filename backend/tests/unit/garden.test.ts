import { describe, expect, it, vi, beforeEach } from "vitest";
import {
  addPlant,
  getGardenPlants,
  updatePlantNickname,
  removePlant,
  type Plant,
} from "../../src/services/garden.js";
import { HttpError } from "../../src/middlewares/errors.js";
import type { Database } from "../../src/config/database.js";

describe("Garden Service Functions", () => {
  const mockDb = {
    plants: {
      create: vi.fn(),
      findMany: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
  } as unknown as Database;

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("addPlant", () => {
    it("thêm cây thành công với dữ liệu hợp lệ", async () => {
      const mockCreatedPlant = {
        id: "plant-123",
        owner_id: "user-abc",
        nickname: "Cây Kim Tiền",
        species_id: "species-1",
        cover_image_key: "img-key.jpg",
        environment: "indoor",
        region_name: null,
        latitude: null,
        longitude: null,
        reference_image_id: null,
        created_at: new Date(),
      };

      vi.mocked(mockDb.plants.create).mockResolvedValue(
        mockCreatedPlant as unknown as Plant,
      );

      const result = await addPlant(
        "user-abc",
        {
          nickname: "  Cây Kim Tiền  ",
          species_id: "species-1",
          cover_image_key: "img-key.jpg",
          environment: "indoor",
        },
        mockDb,
      );

      expect(mockDb.plants.create).toHaveBeenCalledWith({
        data: {
          latitude: null,
          longitude: null,
          region_name: null,
          owner_id: "user-abc",
          nickname: "Cây Kim Tiền",
          species_id: "species-1",
          cover_image_key: "img-key.jpg",
          environment: "indoor",
        },
      });
      expect(result).toEqual(mockCreatedPlant);
    });

    it("báo lỗi 400 nếu nickname rỗng", async () => {
      await expect(
        addPlant("user-abc", { nickname: "   " }, mockDb),
      ).rejects.toThrow(HttpError);
    });

    it("báo lỗi 400 nếu environment không hợp lệ", async () => {
      await expect(
        addPlant(
          "user-abc",
          { nickname: "Sen đá", environment: "mars" },
          mockDb,
        ),
      ).rejects.toThrow(HttpError);
    });
  });

  describe("getGardenPlants", () => {
    it("lấy danh sách cây theo thứ tự created_at desc", async () => {
      const mockList = [
        {
          id: "plant-2",
          owner_id: "user-abc",
          created_at: new Date(2026, 1, 2),
        },
        {
          id: "plant-1",
          owner_id: "user-abc",
          created_at: new Date(2026, 1, 1),
        },
      ];

      vi.mocked(mockDb.plants.findMany).mockResolvedValue(
        mockList as unknown as Plant[],
      );

      const result = await getGardenPlants("user-abc", mockDb);

      expect(mockDb.plants.findMany).toHaveBeenCalledWith({
        where: { owner_id: "user-abc" },
        orderBy: [{ created_at: "desc" }, { id: "desc" }],
      });
      expect(result).toEqual(mockList);
    });

    it("báo lỗi 400 nếu ownerId rỗng", async () => {
      await expect(getGardenPlants("", mockDb)).rejects.toThrow(HttpError);
    });
  });

  describe("updatePlantNickname", () => {
    it("cập nhật nickname thành công khi đúng chủ sở hữu", async () => {
      const existingPlant = {
        id: "plant-123",
        owner_id: "user-abc",
        nickname: "Cây Cũ",
      };
      const updatedPlant = {
        ...existingPlant,
        nickname: "Cây Mới",
      };

      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
        existingPlant as unknown as Plant,
      );
      vi.mocked(mockDb.plants.update).mockResolvedValue(
        updatedPlant as unknown as Plant,
      );

      const result = await updatePlantNickname(
        "plant-123",
        "user-abc",
        "Cây Mới",
        mockDb,
      );

      expect(mockDb.plants.findFirst).toHaveBeenCalledWith({
        where: { id: "plant-123", owner_id: "user-abc" },
      });
      expect(mockDb.plants.update).toHaveBeenCalledWith({
        where: { id: "plant-123" },
        data: { nickname: "Cây Mới" },
      });
      expect(result.nickname).toBe("Cây Mới");
    });

    it("báo lỗi 404 khi không tìm thấy hoặc cây không thuộc về user đó", async () => {
      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(null);

      await expect(
        updatePlantNickname("plant-123", "user-other", "Tên mới", mockDb),
      ).rejects.toThrow(HttpError);

      expect(mockDb.plants.update).not.toHaveBeenCalled();
    });

    it("báo lỗi 400 nếu nickname mới rỗng", async () => {
      await expect(
        updatePlantNickname("plant-123", "user-abc", "   ", mockDb),
      ).rejects.toThrow(HttpError);
    });
  });

  describe("removePlant", () => {
    it("xóa cây thành công khi đúng chủ sở hữu", async () => {
      const existingPlant = {
        id: "plant-123",
        owner_id: "user-abc",
      };

      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
        existingPlant as unknown as Plant,
      );
      vi.mocked(mockDb.plants.delete).mockResolvedValue(
        existingPlant as unknown as Plant,
      );

      const result = await removePlant("plant-123", "user-abc", mockDb);

      expect(mockDb.plants.findFirst).toHaveBeenCalledWith({
        where: { id: "plant-123", owner_id: "user-abc" },
      });
      expect(mockDb.plants.delete).toHaveBeenCalledWith({
        where: { id: "plant-123" },
      });
      expect(result).toEqual(existingPlant);
    });

    it("báo lỗi 404 nếu không đúng chủ sở hữu và không gọi delete", async () => {
      vi.mocked(mockDb.plants.findFirst).mockResolvedValue(null);

      await expect(
        removePlant("plant-123", "user-other", mockDb),
      ).rejects.toThrow(HttpError);

      expect(mockDb.plants.delete).not.toHaveBeenCalled();
    });
  });
});
