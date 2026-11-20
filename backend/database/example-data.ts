import { createHash } from "node:crypto";
import type { Database } from "../src/config/database.js";

// Stable per-account IDs: rerunning preserves edited examples and real data.
function sampleId(owner: string, key: string) {
  const hex = createHash("sha256")
    .update(`plantcare-examples-v1:${owner}:${key}`)
    .digest("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-8${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}
const samples = [
  {
    scientific: "Epipremnum aureum",
    name: "Trầu bà",
    days: 7,
    environment: "indoor",
    note: "Đặt cạnh cửa sổ, theo dõi độ ẩm đất.",
  },
  {
    scientific: "Aloe vera",
    name: "Nha đam",
    days: 14,
    environment: "outdoor",
    note: "Mẫu cây ngoài trời tại TP.HCM để thử thời tiết.",
  },
  {
    scientific: "Ficus lyrata",
    name: "Bàng Singapore",
    days: 10,
    environment: "indoor",
    note: "Mẫu có kết quả chẩn đoán giả lập để thử giao diện.",
  },
];
export async function seedExamples(db: Database, owner: string) {
  const now = new Date();
  const day = 86400000;
  return db.$transaction(
    async (tx) => {
      await tx.$queryRaw`SELECT true AS locked FROM pg_advisory_xact_lock(734103, 1)`;
      await tx.profiles.findUniqueOrThrow({ where: { id: owner } });
      for (const [index, item] of samples.entries()) {
        // Reuse canonical identity without replacing existing care knowledge.
        let species = await tx.plant_species.findFirst({
          where: {
            scientific_name: { equals: item.scientific, mode: "insensitive" },
          },
        });
        species ??= await tx.plant_species.create({
          data: {
            scientific_name: item.scientific,
            common_name: item.name,
            care_status: "draft",
            care_source:
              "SEED_DEMO: dữ liệu minh họa, chưa xác minh; không dùng tự động như kiến thức đã duyệt.",
            water_guide: "[Mẫu] Kiểm tra độ ẩm đất trước khi tưới.",
            light_guide: "[Mẫu] Theo dõi cây ở nơi có ánh sáng phù hợp.",
            soil_guide: "[Mẫu] Dùng giá thể thoát nước.",
            temperature_guide: "[Mẫu] Theo dõi nhiệt độ và tình trạng thực tế.",
            fertilizer_guide:
              "[Mẫu] Tuân theo hướng dẫn trên sản phẩm phân bón.",
          },
        });
        const plantId = sampleId(owner, `plant:${index}`);
        await tx.plants.upsert({
          where: { id: plantId },
          update: {},
          create: {
            id: plantId,
            owner_id: owner,
            species_id: species.id,
            nickname: `[MẪU] ${item.name}`,
            environment: item.environment,
            ...(item.environment === "outdoor"
              ? {
                  region_name: "TP. Hồ Chí Minh",
                  latitude: 10.7769,
                  longitude: 106.7009,
                }
              : {}),
          },
        });
        for (const kind of ["water", "fertilize"]) {
          const scheduleId = sampleId(owner, `schedule:${index}:${kind}`);
          const schedule = await tx.care_schedules.upsert({
            where: { plant_id_kind: { plant_id: plantId, kind } },
            update: {},
            create: {
              id: scheduleId,
              plant_id: plantId,
              kind,
              interval_days: kind === "water" ? item.days : 30,
              local_time: new Date("1970-01-01T08:00:00Z"),
              starts_at: new Date(now.getTime() - 30 * day),
            },
          });
          const taskId = sampleId(owner, `task:${index}:${kind}`);
          const due = new Date(
            now.getTime() +
              (index === 0 && kind === "water" ? -3600000 : (index + 1) * day),
          );
          await tx.care_tasks.upsert({
            where: { id: taskId },
            update: {},
            create: {
              id: taskId,
              plant_id: plantId,
              schedule_id: schedule.id,
              kind,
              due_at: due,
              original_due_at: due,
            },
          });
        }
        for (const [n, kind] of ["water", "note"].entries()) {
          const id = sampleId(owner, `log:${index}:${n}`);
          await tx.care_logs.upsert({
            where: { id },
            update: {},
            create: {
              id,
              plant_id: plantId,
              request_id: id,
              kind,
              performed_at: new Date(now.getTime() - (n + 2) * day),
              note: `[MẪU] ${item.note}`,
            },
          });
        }
        const scanId = sampleId(owner, `scan:${index}`);
        await tx.scans.upsert({
          where: { id: scanId },
          update: {},
          create: {
            id: scanId,
            owner_id: owner,
            plant_id: plantId,
            request_id: scanId,
            species_id: species.id,
            reported_species_name: item.scientific,
            image_key: "seed-demo/no-real-image",
            mode: "both",
            source: "seed-demo",
            is_mock: true,
            health_status: index === 2 ? "suspected" : "healthy",
          },
        });
        if (index === 2)
          await tx.scan_findings.upsert({
            where: { scan_id_position: { scan_id: scanId, position: 1 } },
            update: {},
            create: {
              scan_id: scanId,
              position: 1,
              reported_name: "[Mẫu] Dấu hiệu đốm lá",
              symptoms: "Dữ liệu giả lập: đốm nâu trên lá.",
              possible_cause:
                "Chưa xác định, đây không phải chẩn đoán AI thật.",
              treatment_steps: ["[Mẫu] Quan sát và ghi nhận tình trạng cây."],
              guidance_source: "seed-demo",
            },
          });
        const notificationId = sampleId(owner, `notification:${index}`);
        await tx.notifications.upsert({
          where: { id: notificationId },
          update: {},
          create: {
            id: notificationId,
            owner_id: owner,
            event_key: `seed-demo-v1:${index}`,
            kind: index === 0 ? "water" : "system",
            title: `[MẪU] ${index === 0 ? "Đến lịch tưới Trầu bà" : "Theo dõi " + item.name}`,
            body: "Thông báo minh họa để kiểm tra danh sách và trạng thái đã đọc. Không phải kết quả AI thật.",
            read_at: index === 2 ? now : null,
          },
        });
      }
      return {
        plants: 3,
        schedules: 6,
        tasks: 6,
        logs: 6,
        mock_scans: 3,
        notifications: 3,
      };
    },
    { timeout: 30000 },
  );
}
