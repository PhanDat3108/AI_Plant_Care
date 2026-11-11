import { Router } from "express";
import multer from "multer";
import { HttpError, ok } from "../../shared/errors/http.js";
import type { Config } from "../../config/env.js";
import { providers } from "../../integrations/providers.js";

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 1, fields: 0 },
});
export function scans(config: Config) {
  const router = Router(),
    api = providers(config);
  router.post("/analyze", upload.single("image"), async (req, res) => {
    const image = req.file;
    if (!image) throw new HttpError(400, "IMAGE_REQUIRED", "Hãy chọn một ảnh.");
    const png = image.buffer
      .subarray(0, 8)
      .equals(Buffer.from("89504e470d0a1a0a", "hex"));
    const jpeg = image.buffer
      .subarray(0, 3)
      .equals(Buffer.from("ffd8ff", "hex"));
    if (
      !(png && image.mimetype === "image/png") &&
      !(jpeg && image.mimetype === "image/jpeg")
    )
      throw new HttpError(415, "INVALID_IMAGE", "Chỉ nhận ảnh PNG hoặc JPEG.");
    const species = await api.identify(image.buffer);
    const [diseases, care] = await Promise.all([
      api.assess(image.buffer),
      api.care(species.name),
    ]);
    ok(res, {
      isMock: config.MOCK_EXTERNAL_APIS,
      species,
      diseases,
      care,
      possibleCause: config.MOCK_EXTERNAL_APIS
        ? "Ví dụ minh họa: lá ẩm lâu trong môi trường ít thông thoáng."
        : null,
    });
  });
  return router;
}
