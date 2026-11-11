import { expect, it, vi } from "vitest";
import request from "supertest";
import { randomUUID } from "node:crypto";
import { db } from "../src/config/database.js";
import { createApp } from "../src/app.js";
import { readConfig } from "../src/config/env.js";

// Chạy trên PostgreSQL đã migrate; hai user tạm chỉ tồn tại trong bài test.
it.skipIf(process.env.TEST_DATABASE !== "true")(
  "CRUD isolates two verified owners",
  async () => {
    const a = randomUUID(),
      b = randomUUID();
    const app = createApp(
      readConfig({
        SUPABASE_URL: "https://example.supabase.co",
        SUPABASE_PUBLISHABLE_KEY: "test",
      }),
    );
    const own = request.agent(app).set("Authorization", "Bearer a");
    const other = request.agent(app).set("Authorization", "Bearer b");
    vi.stubGlobal("fetch", async (_url: unknown, init: RequestInit) =>
      Response.json({
        id:
          new Headers(init.headers).get("authorization") === "Bearer a" ? a : b,
      }),
    );
    try {
      const root = "/api/v1/plants";
      const plant = (await own.post(root).send({ name: "Cây thử" }).expect(201))
        .body.data;
      const path = root + "/" + plant.id;
      await own.get(path).expect(200);
      expect((await own.get(root)).body.data).toHaveLength(1);
      expect((await other.get(root)).body.data).toEqual([]);
      await other.get(path).expect(404);
      await other.patch(path).send({ name: "Khác" }).expect(404);
      await other.delete(path).expect(404);
      await own.patch(path).send({ notes: "Ban công" }).expect(200);
      await own.delete(path).expect(200);
      await own.get(path).expect(404);
    } finally {
      vi.unstubAllGlobals();
      await db.userProfile.deleteMany({ where: { id: { in: [a, b] } } });
      await db.$disconnect();
    }
  },
);
