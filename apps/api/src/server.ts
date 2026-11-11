import { readConfig } from "./config/env.js";
import { createApp } from "./app.js";
const config = readConfig(process.env);
createApp(config).listen(config.PORT, "0.0.0.0", () =>
  console.info("AI Plant Care • port", config.PORT),
);
