BEGIN;
ALTER TABLE plantcare.care_schedules ADD COLUMN starts_at timestamptz(3) NOT NULL DEFAULT now();
ALTER TABLE plantcare.notifications ADD COLUMN event_key text;
CREATE UNIQUE INDEX notifications_owner_id_event_key_key ON plantcare.notifications(owner_id, event_key);
COMMIT;
