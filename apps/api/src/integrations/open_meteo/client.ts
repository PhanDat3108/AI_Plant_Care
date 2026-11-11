import { z } from "zod";
import { request } from "../request.js";
import type { WeatherProvider } from "../providers.js";
export const openMeteo: WeatherProvider = {
  async forecast(latitude, longitude) {
    const url = new URL("https://api.open-meteo.com/v1/forecast");
    url.search = new URLSearchParams({
      latitude: String(latitude),
      longitude: String(longitude),
      daily: "temperature_2m_max,precipitation_sum",
      forecast_days: "1",
      timezone: "auto",
    }).toString();
    const values = z.tuple([z.number()]);
    const { daily } = await request(
      url,
      z.object({
        daily: z.object({
          time: z.tuple([z.string()]),
          temperature_2m_max: values,
          precipitation_sum: values,
        }),
      }),
    );
    return {
      date: daily.time[0],
      maxC: daily.temperature_2m_max[0],
      rainMm: daily.precipitation_sum[0],
    };
  },
};
