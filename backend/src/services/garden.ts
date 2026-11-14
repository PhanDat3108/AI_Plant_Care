import type { Database } from "../config/database.js";
import { HttpError } from "../middlewares/errors.js";

export function gardenService(db: Database) {
  return {
    list(ownerId: string, skip: number, take: number) {
      return db.plants.findMany({
        where: { owner_id: ownerId },
        skip,
        take,
        orderBy: [{ created_at: "desc" }, { id: "desc" }],
      });
    },
    async detail(ownerId: string, id: string) {
      const plant = await db.plants.findFirst({
        where: { id, owner_id: ownerId },
      });
      if (!plant) throw new HttpError(404, "NOT_FOUND", "Không tìm thấy cây.");
      const species = plant.species_id
        ? await db.plant_species.findUnique({ where: { id: plant.species_id } })
        : null;
      const referenceImage = plant.reference_image_id
        ? await db.reference_images.findUnique({
            where: { id: plant.reference_image_id },
          })
        : null;
      return { ...plant, species, referenceImage };
    },
  };
}
