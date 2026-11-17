BEGIN;
CREATE TABLE plantcare.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id uuid NOT NULL REFERENCES plantcare.profiles(id) ON DELETE CASCADE,
    kind text NOT NULL CHECK (kind IN ('water','fertilize','system')),
    title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 200),
    body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 4000),
    created_at timestamptz(3) NOT NULL DEFAULT now(),
    read_at timestamptz(3)
);
CREATE INDEX notifications_inbox ON plantcare.notifications (owner_id, created_at DESC, id DESC);
CREATE INDEX notifications_unread ON plantcare.notifications (owner_id) WHERE read_at IS NULL;
COMMIT;
