import { describe, expect, it, vi, beforeEach } from "vitest";
import { addPlant, getGardenPlants, gardenService } from "../../src/services/garden.js";
import { careTaskService } from "../../src/services/care-tasks.js";
import type { Database } from "../../src/config/database.js";
import type { Config } from "../../src/config/env.js";

// Mock plantImageStorage
const mockCreateSignedUrl = vi.fn();
const mockCreateSignedUrls = vi.fn();

vi.mock("../../src/services/plant-image-storage.js", () => ({
  plantImageStorage: vi.fn(() => ({
    upload: vi.fn(),
    createSignedUrl: mockCreateSignedUrl,
    createSignedUrls: mockCreateSignedUrls,
    remove: vi.fn(),
  })),
}));

describe("Garden & Care Tasks cover_image_url Integration", () => {
  const mockConfig: Partial<Config> = {
    SUPABASE_URL: "https://test.supabase.co",
    SUPABASE_SECRET_KEY: "secret",
    SUPABASE_STORAGE_BUCKET: "plant-images",
  };

  const mockDb = {
    plants: {
      create: vi.fn(),
      findMany: vi.fn(),
      findFirst: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
    scans: {
      findFirst: vi.fn(),
    },
    profiles: {
      findUnique: vi.fn(),
    },
    care_tasks: {
      findMany: vi.fn(),
    },
  } as unknown as Database;

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("addPlant with cover_image_key", () => {
    it("ném lỗi 400 INVALID_COVER_IMAGE nếu ảnh không thuộc về ownerId", async () => {
      vi.mocked(mockDb.scans.findFirst).mockResolvedValueOnce(null);

      await expect(
        addPlant(
          "user-1",
          {
            nickname: "Trầu bà",
            cover_image_key: "scans/other-user/photo.jpg",
          },
          mockDb,
          mockConfig as Config,
        ),
      ).rejects.toThrow(
        expect.objectContaining({
          status: 400,
          code: "INVALID_COVER_IMAGE",
        }),
      );

      expect(mockDb.scans.findFirst).toHaveBeenCalledWith({
        where: {
          image_key: "scans/other-user/photo.jpg",
          owner_id: "user-1",
        },
        select: { id: true },
      });
      expect(mockDb.plants.create).not.toHaveBeenCalled();
    });

    it("lưu và trả về cover_image_url khi ảnh hợp lệ và có config", async () => {
      vi.mocked(mockDb.scans.findFirst).mockResolvedValueOnce({ id: "scan-ok" } as never);
      vi.mocked(mockDb.plants.create).mockResolvedValueOnce({
        id: "plant-1",
        owner_id: "user-1",
        nickname: "Trầu bà",
        cover_image_key: "scans/user-1/photo.jpg",
      } as never);
      mockCreateSignedUrl.mockResolvedValueOnce("https://signed.url/photo.jpg");

      const result = await addPlant(
        "user-1",
        {
          nickname: "Trầu bà",
          cover_image_key: "scans/user-1/photo.jpg",
        },
        mockDb,
        mockConfig as Config,
      );

      expect(result.cover_image_url).toBe("https://signed.url/photo.jpg");
      expect(mockCreateSignedUrl).toHaveBeenCalledWith("scans/user-1/photo.jpg");
    });
  });

  describe("getGardenPlants with signed URLs batching", () => {
    it("ký URL theo lô cho danh sách cây", async () => {
      vi.mocked(mockDb.plants.findMany).mockResolvedValueOnce([
        { id: "p1", nickname: "Cây 1", cover_image_key: "scans/u/1.jpg" },
        { id: "p2", nickname: "Cây 2", cover_image_key: null },
        { id: "p3", nickname: "Cây 3", cover_image_key: "scans/u/3.jpg" },
      ] as never);

      mockCreateSignedUrls.mockResolvedValueOnce(
        new Map([
          ["scans/u/1.jpg", "https://signed.url/1.jpg"],
          ["scans/u/3.jpg", "https://signed.url/3.jpg"],
        ]),
      );

      const list = await getGardenPlants("user-1", mockDb, mockConfig as Config);

      expect(list).toHaveLength(3);
      expect(list[0].cover_image_url).toBe("https://signed.url/1.jpg");
      expect(list[1].cover_image_url).toBeNull();
      expect(list[2].cover_image_url).toBe("https://signed.url/3.jpg");
      expect(mockCreateSignedUrls).toHaveBeenCalledWith([
        "scans/u/1.jpg",
        null,
        "scans/u/3.jpg",
      ]);
    });
  });

  describe("gardenService.detail with signed URL", () => {
    it("trả về cover_image_url khi xem chi tiết cây", async () => {
      vi.mocked(mockDb.plants.findFirst).mockResolvedValueOnce({
        id: "p1",
        owner_id: "user-1",
        nickname: "Cây 1",
        cover_image_key: "scans/u/1.jpg",
        species_id: null,
        reference_image_id: null,
      } as never);
      mockCreateSignedUrl.mockResolvedValueOnce("https://signed.url/detail.jpg");

      const service = gardenService(mockDb, mockConfig as Config);
      const detail = await service.detail("user-1", "p1");

      expect(detail.cover_image_url).toBe("https://signed.url/detail.jpg");
      expect(mockCreateSignedUrl).toHaveBeenCalledWith("scans/u/1.jpg");
    });
  });

  describe("careTaskService.list with signed URLs batching", () => {
    it("bổ sung cover_image_url vào care_schedules.plants trong danh sách nhiệm vụ", async () => {
      vi.mocked(mockDb.profiles.findUnique).mockResolvedValueOnce({
        timezone: "Asia/Ho_Chi_Minh",
      } as never);

      vi.mocked(mockDb.care_tasks.findMany).mockResolvedValueOnce([
        {
          id: "task-1",
          state: "pending",
          due_at: new Date(),
          care_schedules: {
            plants: {
              id: "p1",
              nickname: "Cây 1",
              cover_image_key: "scans/u/task1.jpg",
            },
          },
        },
      ] as never);

      mockCreateSignedUrls.mockResolvedValueOnce(
        new Map([["scans/u/task1.jpg", "https://signed.url/task1.jpg"]]),
      );

      const tasksService = careTaskService(mockDb, mockConfig as Config);
      const res = await tasksService.list("user-1", {
        state: "pending",
        limit: 10,
        offset: 0,
      });

      expect(res.items[0].care_schedules.plants?.cover_image_url).toBe(
        "https://signed.url/task1.jpg",
      );
    });
  });
});
