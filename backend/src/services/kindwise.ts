import { z } from "zod";
import { request } from "./request.js";
import { HttpError } from "../middlewares/http.js";
import type {
  PlantIdentificationProvider,
  PlantHealthProvider,
} from "./providers.js";

const suggestions = z.object({
  suggestions: z.array(
    z.object({ name: z.string(), probability: z.number().min(0).max(1) }),
  ),
});
const flag = z.object({ binary: z.boolean() });
export function kindwise(
  key: string,
): PlantIdentificationProvider & PlantHealthProvider {
  function photo(image: Buffer): RequestInit {
    const form = new FormData();
    form.set("image1", new Blob([new Uint8Array(image)]), "plant");
    return { method: "POST", headers: { "Api-Key": key }, body: form };
  }
  return {
    async identify(image) {
      const { result } = await request(
        "https://plant.id/api/v3/identification",
        z.object({
          result: z.object({
            is_plant: flag,
            classification: suggestions.optional(),
          }),
        }),
        photo(image),
      );
      const top = result.classification?.suggestions[0];
      if (!result.is_plant.binary || !top)
        throw new HttpError(
          422,
          "NO_PLANT",
          "Chưa nhận diện được cây trong ảnh.",
        );
      return top;
    },
    async assess(image) {
      const { result } = await request(
        "https://plant.id/api/v3/health_assessment",
        z.object({
          result: z.object({
            is_healthy: flag,
            disease: suggestions.optional(),
          }),
        }),
        photo(image),
      );
      return result.is_healthy.binary
        ? []
        : (result.disease?.suggestions.slice(0, 3) ?? []);
    },
  };
}
