import { describe, it, expect, vi, beforeEach } from "vitest";
import {
  formatSpeciesDisplayName,
  translateSpeciesToVietnamese,
  scanService,
} from "../../src/services/scan.js";
import type { Config } from "../../src/config/env.js";

// Mock plantImageStorage
const mockUpload = vi.fn();
const mockCreateSignedUrl = vi.fn();
const mockCreateSignedUrls = vi.fn();
const mockRemove = vi.fn();

vi.mock("../../src/services/plant-image-storage.js", () => ({
  plantImageStorage: vi.fn(() => ({
    upload: mockUpload,
    createSignedUrl: mockCreateSignedUrl,
    createSignedUrls: mockCreateSignedUrls,
    remove: mockRemove,
  })),
}));

describe("Scan Service", () => {
  const baseConfig: Partial<Config> = {
    GEMINI_API_KEY: "fake-key",
    GEMINI_MODEL: "gemini-3.5-flash-lite",
    CARE_AI_MODE: "demo",
    SUPABASE_URL: "https://test.supabase.co",
    SUPABASE_SECRET_KEY: "test-secret",
    SUPABASE_STORAGE_BUCKET: "plant-images",
  };

  beforeEach(() => {
    vi.clearAllMocks();
    mockRemove.mockResolvedValue(undefined);
  });

  describe("formatSpeciesDisplayName", () => {
    it("định dạng 'Tên tiếng Việt (Tên khoa học)' khi có tên Việt", () => {
      const formatted = formatSpeciesDisplayName("Epipremnum aureum", "Trầu bà");
      expect(formatted).toBe("Trầu bà (Epipremnum aureum)");
    });

    it("chỉ trả về tên khoa học khi không có tên tiếng Việt", () => {
      expect(formatSpeciesDisplayName("Epipremnum aureum", null)).toBe("Epipremnum aureum");
      expect(formatSpeciesDisplayName("Epipremnum aureum", undefined)).toBe("Epipremnum aureum");
      expect(formatSpeciesDisplayName("Epipremnum aureum", "")).toBe("Epipremnum aureum");
      expect(formatSpeciesDisplayName("Epipremnum aureum", "   ")).toBe("Epipremnum aureum");
    });
  });

  describe("translateSpeciesToVietnamese", () => {
    it("trả về null nếu không có GEMINI_API_KEY", async () => {
      const noKeyConfig: Partial<Config> = { ...baseConfig, GEMINI_API_KEY: "" };
      const res = await translateSpeciesToVietnamese("Monstera deliciosa", noKeyConfig as Config);
      expect(res).toBeNull();
    });

    it("bắt lỗi an toàn khi fetch gặp sự cố", async () => {
      const origFetch = global.fetch;
      global.fetch = vi.fn().mockRejectedValueOnce(new Error("Network fail"));

      const res = await translateSpeciesToVietnamese("Monstera deliciosa", baseConfig as Config);
      expect(res).toBeNull();

      global.fetch = origFetch;
    });
  });

  describe("scanService logic", () => {
    it("idempotency check: trả về bản ghi cũ và không upload ảnh mới nếu request_id đã tồn tại", async () => {
      const existingScan = {
        id: "scan-1",
        owner_id: "user-1",
        request_id: "req-1",
        image_key: "scans/user-1/old.jpg",
        mode: "identify",
        scan_findings: [],
      };

      const mockDb = {
        scans: {
          findUnique: vi.fn().mockResolvedValueOnce(existingScan),
        },
      };

      mockCreateSignedUrl.mockResolvedValueOnce("https://signed.url/old.jpg");

      const service = scanService(mockDb as unknown as Parameters<typeof scanService>[0], baseConfig as Config);
      const result = await service.create("user-1", {
        mode: "identify",
        imageBuffer: Buffer.from("image"),
        mimeType: "image/jpeg",
        request_id: "req-1",
      });

      expect(result.isExisting).toBe(true);
      expect(result.image_url).toBe("https://signed.url/old.jpg");
      expect(mockUpload).not.toHaveBeenCalled();
    });

    it("dọn dẹp storage nếu thao tác DB thất bại sau khi upload", async () => {
      mockUpload.mockResolvedValueOnce("scans/user-1/uploaded.jpg");

      const mockDb = {
        scans: {
          findUnique: vi.fn().mockResolvedValueOnce(null),
          create: vi.fn().mockRejectedValueOnce(new Error("DB connection lost")),
        },
        $queryRaw: vi.fn().mockResolvedValueOnce([]),
        plant_species: {
          create: vi.fn().mockResolvedValueOnce({
            id: "sp-1",
            scientific_name: "Epipremnum aureum",
            common_name: "Trầu bà",
          }),
        },
      };

      const service = scanService(mockDb as unknown as Parameters<typeof scanService>[0], baseConfig as Config);

      await expect(
        service.create("user-1", {
          mode: "identify",
          imageBuffer: Buffer.from("image"),
          mimeType: "image/jpeg",
          request_id: "req-new",
        }),
      ).rejects.toThrow("DB connection lost");

      expect(mockRemove).toHaveBeenCalledWith("scans/user-1/uploaded.jpg");
    });

    it("remove scan: chỉ xóa file storage khi không còn cây nào dùng làm cover_image_key", async () => {
      const mockDb = {
        scans: {
          findFirst: vi.fn().mockResolvedValueOnce({
            id: "scan-del",
            owner_id: "user-1",
            image_key: "scans/user-1/photo.jpg",
          }),
          delete: vi.fn().mockResolvedValueOnce({ id: "scan-del" }),
        },
        plants: {
          findFirst: vi.fn().mockResolvedValueOnce(null), // Không có cây nào dùng
        },
      };

      const service = scanService(mockDb as unknown as Parameters<typeof scanService>[0], baseConfig as Config);
      await service.remove("user-1", "scan-del");

      expect(mockRemove).toHaveBeenCalledWith("scans/user-1/photo.jpg");
    });

    it("remove scan: KHÔNG xóa file storage nếu vẫn có cây trong vườn dùng làm cover_image_key", async () => {
      const mockDb = {
        scans: {
          findFirst: vi.fn().mockResolvedValueOnce({
            id: "scan-del",
            owner_id: "user-1",
            image_key: "scans/user-1/photo.jpg",
          }),
          delete: vi.fn().mockResolvedValueOnce({ id: "scan-del" }),
        },
        plants: {
          findFirst: vi.fn().mockResolvedValueOnce({ id: "plant-1" }), // Đang được dùng làm ảnh bìa
        },
      };

      const service = scanService(mockDb as unknown as Parameters<typeof scanService>[0], baseConfig as Config);
      await service.remove("user-1", "scan-del");

      expect(mockRemove).not.toHaveBeenCalled();
    });
  });
});
