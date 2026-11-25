import { expect, it, vi } from 'vitest';
import { scheduleService } from '../../src/services/schedules.js';

it('returns pending dates only for enabled schedules and checks ownership', async () => {
  const task = { id: 'task-1', due_at: new Date('2026-11-27T01:00:00Z'), adjustment_reason: 'rain' };
  const findFirst = vi.fn().mockResolvedValue({
    profiles: { timezone: 'Asia/Ho_Chi_Minh' },
    care_schedules: [
      { enabled: true, local_time: new Date('1970-01-01T08:00:00Z'), care_tasks: [task] },
      { enabled: false, local_time: new Date('1970-01-01T09:00:00Z'), care_tasks: [{ id: 'disabled-task' }] },
    ],
  });
  const service = scheduleService({ plants: { findFirst } } as unknown as Parameters<typeof scheduleService>[0]);
  const result = await service.list('owner-1', 'plant-1');
  expect(findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'plant-1', owner_id: 'owner-1' } }));
  expect(result.tasks).toEqual([task]);
  expect(result.items[0].local_time).toBe('08:00');
  findFirst.mockResolvedValueOnce(null);
  await expect(service.list('other-owner', 'plant-1')).rejects.toMatchObject({ code: 'NOT_FOUND' });
});
