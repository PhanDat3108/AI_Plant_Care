BEGIN;
ALTER TABLE plantcare.notifications ADD CONSTRAINT notifications_owner_id_id_key UNIQUE(owner_id, id);
CREATE TABLE plantcare.push_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES plantcare.profiles(id) ON DELETE CASCADE,
  installation_id uuid NOT NULL UNIQUE,
  token text NOT NULL UNIQUE CHECK (char_length(token) BETWEEN 20 AND 4096),
  platform text NOT NULL CHECK (platform IN ('android','ios')),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz(3) NOT NULL DEFAULT now(),
  updated_at timestamptz(3) NOT NULL DEFAULT now(),
  UNIQUE(owner_id, id)
);
CREATE INDEX push_devices_owner_id_active_idx ON plantcare.push_devices(owner_id, active);
CREATE TABLE plantcare.push_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  notification_id uuid NOT NULL,
  device_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','processing','sent','failed','skipped')),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  available_at timestamptz(3) NOT NULL DEFAULT now(),
  expires_at timestamptz(3) NOT NULL,
  lease_id uuid,
  locked_until timestamptz(3),
  sent_at timestamptz(3),
  last_error text,
  FOREIGN KEY(owner_id, notification_id) REFERENCES plantcare.notifications(owner_id, id) ON DELETE CASCADE,
  FOREIGN KEY(owner_id, device_id) REFERENCES plantcare.push_devices(owner_id, id) ON DELETE CASCADE,
  UNIQUE(notification_id, device_id)
);
CREATE INDEX push_deliveries_status_available_at_idx ON plantcare.push_deliveries(status, available_at);
CREATE INDEX push_deliveries_device_id_idx ON plantcare.push_deliveries(device_id);
-- Server-only tables: clients access them through authenticated backend APIs.
ALTER TABLE plantcare.push_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE plantcare.push_deliveries ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION plantcare.enqueue_notification_push() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.kind IN ('water', 'fertilize') AND NEW.event_key LIKE 'care-task:%' THEN
    INSERT INTO plantcare.push_deliveries
      (owner_id, notification_id, device_id, available_at, expires_at)
    SELECT NEW.owner_id, NEW.id, d.id, NEW.created_at, NEW.created_at + interval '24 hours'
    FROM plantcare.push_devices d
    WHERE d.owner_id = NEW.owner_id AND d.active;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER notifications_enqueue_push AFTER INSERT ON plantcare.notifications
FOR EACH ROW EXECUTE FUNCTION plantcare.enqueue_notification_push();
COMMIT;
