-- task_id đã unique. Index ghép giúp Prisma biểu diễn quan hệ 1-1 qua khóa ngoại ghép.
CREATE UNIQUE INDEX care_logs_task_plant_kind
    ON plantcare.care_logs(task_id, plant_id, kind);
