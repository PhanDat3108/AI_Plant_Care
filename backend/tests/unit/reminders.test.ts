import { describe, expect, it, vi } from "vitest";
import type { Database } from "../../src/config/database.js";
import { reminderService } from "../../src/services/reminders.js";

function fixture() {
  const findMany = vi.fn();
  const sync = vi.fn();
  const db = { plants: { findMany } } as unknown as Database;
  return { findMany, sync, service: reminderService(db, { sync }) };
}

describe("Reminder service", () => {
  it("continues across batches and a failed plant, preserving owner and totals", async () => {
    const { findMany, sync, service } = fixture();
    findMany
      .mockResolvedValueOnce([
        { id: "plant-a", owner_id: "owner-a" },
        { id: "plant-b", owner_id: "owner-b" },
      ])
      .mockResolvedValueOnce([{ id: "plant-c", owner_id: "owner-c" }])
      .mockResolvedValueOnce([]);
    sync
      .mockResolvedValueOnce({ notifications_created: 2 })
      .mockRejectedValueOnce(new Error("failed plant"))
      .mockResolvedValueOnce({ notifications_created: 1 });
    const onPlantError = vi.fn();

    await expect(service.runOnce({ onPlantError })).resolves.toEqual({
      processed: 2,
      failed: 1,
      notifications_created: 3,
    });
    expect(sync.mock.calls).toEqual([
      ["owner-a", "plant-a"],
      ["owner-b", "plant-b"],
      ["owner-c", "plant-c"],
    ]);
    expect(findMany.mock.calls.map(([query]) => query.where)).toEqual([
      {},
      { id: { gt: "plant-b" } },
      { id: { gt: "plant-c" } },
    ]);
    expect(onPlantError).toHaveBeenCalledExactlyOnceWith("plant-b");
  });

  it("finishes the active plant then stops without processing the next one", async () => {
    const { findMany, sync, service } = fixture();
    findMany.mockResolvedValue([
      { id: "plant-a", owner_id: "owner-a" },
      { id: "plant-b", owner_id: "owner-b" },
    ]);
    let stopped = false;
    sync.mockImplementation(async () => {
      stopped = true;
      return { notifications_created: 1 };
    });
    await expect(
      service.runOnce({ shouldStop: () => stopped }),
    ).resolves.toEqual({
      processed: 1,
      failed: 0,
      notifications_created: 1,
    });
    expect(sync).toHaveBeenCalledOnce();
    expect(findMany).toHaveBeenCalledOnce();
  });

  it("propagates database scan failures to the job", async () => {
    const { findMany, sync, service } = fixture();
    findMany.mockRejectedValue(new Error("database unavailable"));
    await expect(service.runOnce()).rejects.toThrow("database unavailable");
    expect(sync).not.toHaveBeenCalled();
  });
});
