import { z } from "zod";
import { request } from "./request.js";
import type { PlantCareDataProvider } from "./providers.js";

export function perenual(key: string): PlantCareDataProvider {
  return {
    async care(name) {
      const url = new URL("https://perenual.com/api/v2/species-list");
      url.searchParams.set("key", key);
      url.searchParams.set("q", name);
      const { data } = await request(
        url,
        z.object({
          data: z.array(
            z.object({
              id: z.number().int(),
              scientific_name: z.array(z.string()),
            }),
          ),
        }),
      );
      const match = data.find((row) =>
        row.scientific_name.some((n) => n.toLowerCase() === name.toLowerCase()),
      );
      if (!match) return "Chưa có hướng dẫn cho loài này.";
      const details = new URL(
        "https://perenual.com/api/v2/species/details/" + match.id,
      );
      details.searchParams.set("key", key);
      const plant = await request(
        details,
        z.object({
          watering: z.string().nullish(),
          sunlight: z.array(z.string()).nullish(),
        }),
      );
      return (
        "Nhu cầu nước: " +
        (plant.watering ?? "chưa rõ") +
        ". Ánh sáng: " +
        (plant.sunlight?.join(", ") || "chưa rõ") +
        "."
      );
    },
  };
}
