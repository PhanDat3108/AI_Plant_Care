import { describe, it, expect, vi, beforeEach } from "vitest";
import { plantImageStorage } from "../../src/services/plant-image-storage.js";
import type { Config } from "../../src/config/env.js";

// Mock @supabase/supabase-js
const mockUpload = vi.fn();
const mockCreateSignedUrl = vi.fn();
const mockCreateSignedUrls = vi.fn();
const mockRemove = vi.fn();

vi.mock("@supabase/supabase-js", () => ({
  createClient: vi.fn(() => ({
    storage: {
      from: vi.fn(() => ({
        upload: mockUpload,
        createSignedUrl: mockCreateSignedUrl,
        createSignedUrls: mockCreateSignedUrls,
        remove: mockRemove,
      })),
    },
  })),
}));

describe("plantImageStorage", () => {
  const baseConfig: Partial<Config> = {
    SUPABASE_URL: "https://test.supabase.co",
    SUPABASE_SECRET_KEY: "secret-key",
    SUPABASE_STORAGE_BUCKET: "plant-images",
    CARE_AI_MODE: "auto",
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("upload", () => {
    it("upload thành công và trả về object key chuẩn", async () => {
      mockUpload.mockResolvedValueOnce({ data: { path: "some-path" }, error: null });

      const storage = plantImageStorage(baseConfig as Config);
      const buffer = Buffer.from("fake-image");
      const key = await storage.upload(buffer, "image/png", "user-123");

      expect(key).toMatch(/^scans\/user-123\/[a-f0-9-]+\.png$/);
      expect(mockUpload).toHaveBeenCalledWith(
        key,
        buffer,
        { contentType: "image/png", upsert: false },
      );
    });

    it("chế độ demo: trả về mock key mà không gọi supabase khi chưa cấu hình", async () => {
      const demoConfig: Partial<Config> = {
        ...baseConfig,
        SUPABASE_SECRET_KEY: "",
        CARE_AI_MODE: "demo",
      };

      const storage = plantImageStorage(demoConfig as Config);
      const key = await storage.upload(Buffer.from("img"), "image/jpeg", "user-demo");

      expect(key).toMatch(/^scans\/user-demo\/[a-f0-9-]+\.jpg$/);
      expect(mockUpload).not.toHaveBeenCalled();
    });

    it("ném lỗi 503 STORAGE_UNAVAILABLE khi chưa cấu hình storage", async () => {
      const unconfigured: Partial<Config> = {
        ...baseConfig,
        SUPABASE_SECRET_KEY: "",
        CARE_AI_MODE: "live",
      };

      const storage = plantImageStorage(unconfigured as Config);
      await expect(
        storage.upload(Buffer.from("img"), "image/webp", "user-1"),
      ).rejects.toThrow("Chưa cấu hình Supabase Storage.");
    });
  });

  describe("createSignedUrl", () => {
    it("trả về signedUrl khi tạo thành công", async () => {
      mockCreateSignedUrl.mockResolvedValueOnce({
        data: { signedUrl: "https://storage.signed.url/image.jpg" },
        error: null,
      });

      const storage = plantImageStorage(baseConfig as Config);
      const url = await storage.createSignedUrl("scans/user/photo.jpg", 1800);

      expect(url).toBe("https://storage.signed.url/image.jpg");
      expect(mockCreateSignedUrl).toHaveBeenCalledWith("scans/user/photo.jpg", 1800);
    });

    it("trả về null nếu key rỗng", async () => {
      const storage = plantImageStorage(baseConfig as Config);
      const url = await storage.createSignedUrl("");
      expect(url).toBeNull();
    });
  });

  describe("createSignedUrls", () => {
    it("trả về Map danh sách signedUrl theo lô", async () => {
      mockCreateSignedUrls.mockResolvedValueOnce({
        data: [
          { path: "key1.jpg", signedUrl: "https://signed.url/key1.jpg", error: null },
          { path: "key2.png", signedUrl: "https://signed.url/key2.png", error: null },
        ],
        error: null,
      });

      const storage = plantImageStorage(baseConfig as Config);
      const map = await storage.createSignedUrls(["key1.jpg", "key2.png", "key1.jpg"]);

      expect(map.size).toBe(2);
      expect(map.get("key1.jpg")).toBe("https://signed.url/key1.jpg");
      expect(map.get("key2.png")).toBe("https://signed.url/key2.png");
    });
  });

  describe("remove", () => {
    it("gọi remove thành công", async () => {
      mockRemove.mockResolvedValueOnce({ data: [], error: null });

      const storage = plantImageStorage(baseConfig as Config);
      await storage.remove("scans/user/photo.jpg");

      expect(mockRemove).toHaveBeenCalledWith(["scans/user/photo.jpg"]);
    });
  });
});
