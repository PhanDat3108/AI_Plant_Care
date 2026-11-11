import type { Response, ErrorRequestHandler } from "express";
import { Prisma } from "@prisma/client";
import { ZodError } from "zod";
import multer from "multer";

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}
export function ok(res: Response, data: unknown, status = 200) {
  res.status(status).json({ success: true, data, error: null, message: "OK" });
}
function classify(err: unknown) {
  if (err instanceof HttpError) return err;
  if (err instanceof ZodError)
    return new HttpError(400, "INVALID_INPUT", "Dữ liệu gửi lên chưa hợp lệ.");
  if (err instanceof multer.MulterError)
    return err.code === "LIMIT_FILE_SIZE"
      ? new HttpError(413, "IMAGE_TOO_LARGE", "Ảnh vượt quá 5 MiB.")
      : new HttpError(
          400,
          "INVALID_UPLOAD",
          "Hãy gửi một ảnh trong trường image.",
        );
  if (
    err instanceof Prisma.PrismaClientKnownRequestError &&
    err.code === "P2025"
  )
    return new HttpError(404, "NOT_FOUND", "Không tìm thấy cây.");
  if (err instanceof Prisma.PrismaClientInitializationError)
    return new HttpError(
      503,
      "DATABASE_UNAVAILABLE",
      "Chưa kết nối được cơ sở dữ liệu.",
    );
  if (
    err instanceof Error &&
    "status" in err &&
    (err.status === 400 || err.status === 413)
  )
    return new HttpError(
      err.status,
      "INVALID_BODY",
      "Nội dung yêu cầu chưa hợp lệ.",
    );
  return new HttpError(500, "INTERNAL_ERROR", "Máy chủ gặp lỗi.");
}
// Express nhận diện error middleware thông qua bốn tham số.
export const errors: ErrorRequestHandler = (err, req, res, next) => {
  if (res.headersSent) return next(err);
  const e = classify(err);
  if (e.status >= 500) console.error(req.method, req.path, e.code);
  res
    .status(e.status)
    .json({
      success: false,
      data: null,
      error: { code: e.code },
      message: e.message,
    });
};
