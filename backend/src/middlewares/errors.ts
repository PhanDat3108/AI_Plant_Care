import type { ErrorRequestHandler, Response } from "express";
import { ZodError } from "zod";

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}
export function success(res: Response, data: unknown) {
  res.json({ success: true, data, error: null, message: "OK" });
}
export const errors: ErrorRequestHandler = (
  error: unknown,
  _req,
  res,
  next,
) => {
  if (res.headersSent) return next(error);
  let failure = new HttpError(
    500,
    "INTERNAL_ERROR",
    "Máy chủ chưa hoàn tất yêu cầu.",
  );
  if (error instanceof HttpError) failure = error;
  if (error instanceof ZodError)
    failure = new HttpError(
      400,
      "INVALID_INPUT",
      "Dữ liệu gửi lên chưa hợp lệ.",
    );
  if (
    error instanceof Error &&
    "status" in error &&
    [400, 413].includes(Number(error.status))
  ) {
    failure = new HttpError(
      Number(error.status),
      "INVALID_BODY",
      "Nội dung yêu cầu chưa hợp lệ.",
    );
  }
  if (failure.status >= 500) console.error(res.locals.requestId, failure.code);
  res.status(failure.status).json({
    success: false,
    data: null,
    error: { code: failure.code },
    message: failure.message,
  });
};
