import { describe, expect, it, vi, beforeEach } from "vitest";
import express from "express";
import request from "supertest";
import { careLogsRoutes } from "../../src/routes/care-logs.js";
import type { Database } from "../../src/config/database.js";
import type { CareLog } from "../../src/services/care-logs.js";
import type { plantsModel } from "../../src/generated/prisma/models/plants.js";

describe("careLogsRoutes", () => {
  let app: express.Express;
  let mockDb: Database;

  beforeEach(() => {
    vi.clearAllMocks();
    mockDb = {
      care_logs: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
      plants: {
        findFirst: vi.fn(),
      },
      care_tasks: {
        findUnique: vi.fn(),
        update: vi.fn(),
        updateMany: vi.fn(),
      },
      $transaction: vi.fn(async (callback: (tx: typeof mockDb) => Promise<unknown>) =>
        callback(mockDb),
      ),
    } as unknown as Database;

    app = express();
    app.use(express.json());

    // Mock authenticate middleware gắn user
    app.use((req, res, next) => {
      res.locals.user = { id: "user-123" };
      next();
    });

    app.use(careLogsRoutes(mockDb));
  });

  it("POST /plants/:id/care-logs - trả về 201 khi tạo thành công", async () => {
    const mockPlant = { id: "plant-123", owner_id: "user-123" };
    const mockLog = {
      id: "log-1",
      plant_id: "plant-123",
      kind: "water",
      note: "Tưới cây buổi sáng",
    } as unknown as CareLog;

    vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(null);
    vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
      mockPlant as unknown as plantsModel,
    );
    vi.mocked(mockDb.care_logs.create).mockResolvedValue(mockLog);

    const res = await request(app)
      .post("/plants/plant-123/care-logs")
      .send({ kind: "water", note: "Tưới cây buổi sáng" })
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(res.body.data.id).toBe("log-1");
  });

  it("GET /plants/:id/care-logs - trả về 200 khi lấy danh sách nhật ký", async () => {
    const mockPlant = { id: "plant-123", owner_id: "user-123" };
    const mockLogs = [
      { id: "log-1", kind: "water" },
    ] as unknown as CareLog[];

    vi.mocked(mockDb.plants.findFirst).mockResolvedValue(
      mockPlant as unknown as plantsModel,
    );
    vi.mocked(mockDb.care_logs.findMany).mockResolvedValue(mockLogs);

    const res = await request(app)
      .get("/plants/plant-123/care-logs?kind=water")
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(res.body.data).toHaveLength(1);
  });

  it("PATCH /care-logs/:logId - trả về 200 khi cập nhật nhật ký", async () => {
    const existing = {
      id: "log-1",
      task_id: null,
      plants: { id: "plant-123", owner_id: "user-123" },
    };
    const mockUpdated = {
      id: "log-1",
      note: "Ghi chú sửa đổi",
    } as unknown as CareLog;

    vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(
      existing as unknown as CareLog,
    );
    vi.mocked(mockDb.care_logs.update).mockResolvedValue(mockUpdated);

    const res = await request(app)
      .patch("/care-logs/log-1")
      .send({ note: "Ghi chú sửa đổi" })
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(res.body.data.note).toBe("Ghi chú sửa đổi");
  });

  it("DELETE /care-logs/:logId - trả về 200 khi xóa nhật ký", async () => {
    const existing = {
      id: "log-1",
      task_id: null,
      plants: { id: "plant-123", owner_id: "user-123" },
    };
    const mockDeleted = {
      id: "log-1",
    } as unknown as CareLog;

    vi.mocked(mockDb.care_logs.findUnique).mockResolvedValue(
      existing as unknown as CareLog,
    );
    vi.mocked(mockDb.care_logs.delete).mockResolvedValue(mockDeleted);

    const res = await request(app)
      .delete("/care-logs/log-1")
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(res.body.data.id).toBe("log-1");
  });
});
