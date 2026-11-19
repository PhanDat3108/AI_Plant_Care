import { describe, expect, it, vi, beforeEach } from "vitest";
import express from "express";
import request from "supertest";
import { gardenRoutes } from "../../src/routes/garden.js";
import * as gardenServiceModule from "../../src/services/garden.js";
import type { Database } from "../../src/config/database.js";

describe("Garden Routes Integration", () => {
  const mockDb = {
    plants: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
  } as unknown as Database;

  let app: express.Express;

  beforeEach(() => {
    vi.clearAllMocks();
    app = express();
    app.use(express.json());

    // Giả lập middleware gắn user đăng nhập
    app.use((req, res, next) => {
      res.locals.user = { id: "user-test-123" };
      next();
    });

    app.use("/plants", gardenRoutes(mockDb));
  });

  it("POST /plants - thêm cây trả về 201", async () => {
    const mockCreated = {
      id: "plant-1",
      owner_id: "user-test-123",
      nickname: "Kim Tiền",
      environment: "indoor",
    } as unknown as gardenServiceModule.Plant;

    vi.spyOn(gardenServiceModule, "addPlant").mockResolvedValue(mockCreated);

    const res = await request(app)
      .post("/plants")
      .send({ nickname: "Kim Tiền", environment: "indoor" })
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(res.body.data.id).toBe("plant-1");
  });

  it("GET /plants - lấy danh sách cây trả về 200", async () => {
    const mockList = [
      { id: "plant-1", nickname: "Cây 1", owner_id: "user-test-123" },
    ] as unknown as gardenServiceModule.Plant[];

    vi.spyOn(gardenServiceModule, "getGardenPlants").mockResolvedValue(mockList);

    const res = await request(app).get("/plants").expect(200);

    expect(res.body.success).toBe(true);
    expect(res.body.data).toHaveLength(1);
  });

  it("PATCH /plants/:id/nickname - đổi tên cây trả về 200", async () => {
    const mockUpdated = {
      id: "plant-1",
      nickname: "Kim Ngân",
      owner_id: "user-test-123",
    } as unknown as gardenServiceModule.Plant;

    vi.spyOn(gardenServiceModule, "updatePlantNickname").mockResolvedValue(mockUpdated);

    const res = await request(app)
      .patch("/plants/plant-1/nickname")
      .send({ nickname: "Kim Ngân" })
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(res.body.data.nickname).toBe("Kim Ngân");
  });

  it("DELETE /plants/:id - xóa cây trả về 200", async () => {
    const mockRemoved = {
      id: "plant-1",
      owner_id: "user-test-123",
    } as unknown as gardenServiceModule.Plant;

    vi.spyOn(gardenServiceModule, "removePlant").mockResolvedValue(mockRemoved);

    const res = await request(app).delete("/plants/plant-1").expect(200);

    expect(res.body.success).toBe(true);
    expect(res.body.data.id).toBe("plant-1");
  });
});
