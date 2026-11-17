import { readConfig } from "../config/env.js";
import { createCareProvider } from "../services/gemini-care.js";
import { HttpError } from "../middlewares/errors.js";

// Provider-only smoke check: no DB reads/writes and no credentials in output.
const config = readConfig(process.env);
const provider = createCareProvider(config);
const scientificName = process.argv[2] ?? "Epipremnum aureum";
if (!scientificName.trim() || scientificName.length > 200)
  throw new Error("Tên loài không hợp lệ.");
try {
  const proposal = await provider.generate({
    scientific_name: scientificName,
    common_name: null,
    sources: [],
  });
  console.info(
    JSON.stringify(
      {
        provider: provider.provider,
        model: provider.model,
        is_mock: provider.isMock,
        status: "draft",
        saved_to_database: false,
        proposal,
      },
      null,
      2,
    ),
  );
} catch (error) {
  console.error(error instanceof HttpError ? error.code : "CARE_CHECK_FAILED");
  process.exitCode = 1;
}
