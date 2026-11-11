import { z } from "zod";
import { HttpError } from "../shared/errors/http.js";
export async function request<T>(
  url: URL | string,
  schema: z.ZodType<T>,
  options: RequestInit = {},
): Promise<T> {
  try {
    const res = await fetch(url, {
      ...options,
      signal: AbortSignal.timeout(18000),
    });
    if (!res.ok) throw new Error();
    return schema.parse(await res.json());
  } catch {
    throw new HttpError(
      502,
      "PROVIDER_UNAVAILABLE",
      "Dịch vụ bên ngoài chưa trả được kết quả hợp lệ.",
    );
  }
}
