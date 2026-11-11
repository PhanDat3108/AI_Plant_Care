import type { Config } from "../config/env.js";
import { kindwise } from "./kindwise.js";
import { perenual } from "./perenual.js";
import { openMeteo } from "./open_meteo.js";

export type Prediction = { name: string; probability: number };
export interface PlantIdentificationProvider {
  identify(image: Buffer): Promise<Prediction>;
}
export interface PlantHealthProvider {
  assess(image: Buffer): Promise<Prediction[]>;
}
export interface PlantCareDataProvider {
  care(scientificName: string): Promise<string>;
}
export interface WeatherProvider {
  forecast(
    latitude: number,
    longitude: number,
  ): Promise<{ maxC: number; rainMm: number; date: string }>;
}
type Providers = PlantIdentificationProvider &
  PlantHealthProvider &
  PlantCareDataProvider &
  WeatherProvider;
export function providers(config: Config): Providers {
  if (config.MOCK_EXTERNAL_APIS)
    return {
      async identify() {
        return { name: "Epipremnum aureum", probability: 0.94 };
      },
      async assess() {
        return [
          { name: "Đốm lá", probability: 0.62 },
          { name: "Vàng lá", probability: 0.28 },
        ];
      },
      async care() {
        return "Đặt cây ở nơi có ánh sáng gián tiếp. Kiểm tra độ ẩm của đất trước khi tưới.";
      },
      async forecast() {
        return {
          date: new Date().toISOString().slice(0, 10),
          maxC: 30,
          rainMm: 2,
        };
      },
    };
  return {
    ...kindwise(config.KINDWISE_API_KEY!),
    ...perenual(config.PERENUAL_API_KEY!),
    ...openMeteo,
  };
}
