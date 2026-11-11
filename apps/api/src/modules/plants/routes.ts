import { Router } from "express";
import { z } from "zod";
import { db } from "../../config/database.js";
import { ok, HttpError } from "../../shared/errors/http.js";

const input = z.strictObject({
  name: z.string().trim().min(1).max(100),
  notes: z.string().trim().max(2000).optional(),
});
export const plants = Router();
plants.get("/", async (_req, res) =>
  ok(
    res,
    await db.userPlant.findMany({
      where: { ownerId: res.locals.ownerId },
      include: { species: true },
      orderBy: { createdAt: "desc" },
    }),
  ),
);
plants.post("/", async (req, res) => {
  const values = input.parse(req.body);
  const ownerId: string = res.locals.ownerId;
  const plant = await db.$transaction(async (tx) => {
    await tx.userProfile.upsert({
      where: { id: ownerId },
      create: { id: ownerId },
      update: {},
    });
    return tx.userPlant.create({ data: { ...values, ownerId } });
  });
  ok(res, plant, 201);
});
plants.get("/:id", async (req, res) => {
  const plant = await db.userPlant.findFirstOrThrow({
    where: { id: z.uuid().parse(req.params.id), ownerId: res.locals.ownerId },
    include: { species: true },
  });
  ok(res, plant);
});
plants.patch("/:id", async (req, res) => {
  const data = input.partial().parse(req.body);
  if (!Object.keys(data).length)
    throw new HttpError(
      400,
      "INVALID_INPUT",
      "Chọn ít nhất một trường cần sửa.",
    );
  ok(
    res,
    await db.userPlant.update({
      where: { id: z.uuid().parse(req.params.id), ownerId: res.locals.ownerId },
      data,
    }),
  );
});
plants.delete("/:id", async (req, res) => {
  await db.userPlant.delete({
    where: { id: z.uuid().parse(req.params.id), ownerId: res.locals.ownerId },
  });
  ok(res, null);
});
