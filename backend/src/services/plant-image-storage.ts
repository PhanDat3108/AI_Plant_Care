import { randomUUID } from "node:crypto";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Config } from "../config/env.js";
import { HttpError } from "../middlewares/errors.js";

const MIME_TO_EXT: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

export function plantImageStorage(config: Config) {
  const isStorageConfigured = Boolean(
    config.SUPABASE_URL && config.SUPABASE_SECRET_KEY,
  );

  let client: SupabaseClient | null = null;
  if (isStorageConfigured) {
    client = createClient(config.SUPABASE_URL!, config.SUPABASE_SECRET_KEY, {
      auth: { persistSession: false },
    });
  }

  const bucket = config.SUPABASE_STORAGE_BUCKET;

  return {
    /**
     * Upload buffer ảnh trực tiếp lên Supabase Storage bucket.
     * Trả về object key theo format `scans/${ownerId}/${randomUUID()}.${ext}`.
     */
    async upload(
      buffer: Buffer,
      mimeType: string,
      ownerId: string,
    ): Promise<string> {
      const ext = MIME_TO_EXT[mimeType] ?? "jpg";
      const objectKey = `scans/${ownerId}/${randomUUID()}.${ext}`;

      if (!client) {
        if (config.CARE_AI_MODE === "demo") {
          return objectKey;
        }
        throw new HttpError(
          503,
          "STORAGE_UNAVAILABLE",
          "Chưa cấu hình Supabase Storage.",
        );
      }

      const { error } = await client.storage.from(bucket).upload(objectKey, buffer, {
        contentType: mimeType,
        upsert: false,
      });

      if (error) {
        throw new HttpError(
          502,
          "STORAGE_UPLOAD_FAILED",
          `Upload ảnh lên storage thất bại: ${error.message}`,
        );
      }

      return objectKey;
    },

    /**
     * Tạo signed URL có thời hạn cho một object key.
     * Trả về null nếu objectKey rỗng hoặc storage chưa sẵn sàng.
     */
    async createSignedUrl(
      objectKey: string | null | undefined,
      expiresIn = 3600,
    ): Promise<string | null> {
      if (!objectKey || !objectKey.trim() || !client) {
        return null;
      }

      const { data, error } = await client.storage
        .from(bucket)
        .createSignedUrl(objectKey.trim(), expiresIn);

      if (error || !data?.signedUrl) {
        return null;
      }

      return data.signedUrl;
    },

    /**
     * Tạo signed URLs hàng loạt cho danh sách object keys.
     * Lọc danh sách key duy nhất khác rỗng và trả về Map<objectKey, signedUrl>.
     */
    async createSignedUrls(
      objectKeys: Array<string | null | undefined>,
      expiresIn = 3600,
    ): Promise<Map<string, string>> {
      const result = new Map<string, string>();
      if (!client) {
        return result;
      }

      const uniqueKeys = Array.from(
        new Set(
          objectKeys
            .map((k) => k?.trim())
            .filter((k): k is string => Boolean(k && k.length > 0)),
        ),
      );

      if (uniqueKeys.length === 0) {
        return result;
      }

      const { data, error } = await client.storage
        .from(bucket)
        .createSignedUrls(uniqueKeys, expiresIn);

      if (error || !data) {
        return result;
      }

      for (const item of data) {
        if (item.signedUrl && item.path) {
          result.set(item.path, item.signedUrl);
        }
      }

      return result;
    },

    /**
     * Xóa object khỏi bucket.
     */
    async remove(objectKey: string): Promise<void> {
      if (!objectKey || !objectKey.trim() || !client) {
        return;
      }

      const { error } = await client.storage
        .from(bucket)
        .remove([objectKey.trim()]);

      if (error) {
        throw new HttpError(
          502,
          "STORAGE_DELETE_FAILED",
          `Xóa ảnh khỏi storage thất bại: ${error.message}`,
        );
      }
    },
  };
}

export type PlantImageStorage = ReturnType<typeof plantImageStorage>;
