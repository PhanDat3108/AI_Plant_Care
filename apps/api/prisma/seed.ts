import "dotenv/config";
import { db } from "../src/config/database.js";
import { demoUserId } from "../src/modules/users/demo.js";

try {
  await db.$transaction(async (tx) => {
    await tx.userProfile.upsert({
      where: { id: demoUserId },
      create: { id: demoUserId },
      update: {},
    });
    const examples = [
      ["Epipremnum aureum", "Trầu bà", "Kiểm tra độ ẩm đất"],
      ["Aloe vera", "Nha đam", "Kiểm tra đất và tưới nếu khô"],
    ];
    for (const [i, [scientificName, commonName, task]] of examples.entries()) {
      const species = await tx.plantSpecies.upsert({
        where: { scientificName },
        create: { scientificName, commonName },
        update: { commonName },
      });
      const plantId = "00000000-0000-4000-8100-00000000000" + i;
      const scheduleId = "00000000-0000-4000-8200-00000000000" + i;
      await tx.userPlant.upsert({
        where: { id: plantId },
        create: {
          id: plantId,
          ownerId: demoUserId,
          speciesId: species.id,
          name: commonName,
          notes: "Cây mẫu của nhóm",
        },
        update: {},
      });
      await tx.careSchedule.upsert({
        where: { id: scheduleId },
        create: {
          id: scheduleId,
          plantId,
          task,
          dueAt: new Date(Date.now() + 86400000 * (i + 1)),
        },
        update: {},
      });
    }
  });
} finally {
  await db.$disconnect();
}
