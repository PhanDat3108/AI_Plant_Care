import { Router } from "express";
import { db } from "../config/database.js";
import { ok } from "../middlewares/http.js";
export const care = Router();
care.get("/", async (_req, res) =>
  ok(
    res,
    await db.careSchedule.findMany({
      where: { plant: { ownerId: res.locals.ownerId } },
      include: { plant: { select: { id: true, name: true } } },
      orderBy: { dueAt: "asc" },
    }),
  ),
);
