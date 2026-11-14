-- PostgreSQL 16+. Chạy một lần trên DB mới. Backend truy cập schema riêng bằng SQL.
BEGIN;
CREATE SCHEMA plantcare;
REVOKE ALL ON SCHEMA plantcare FROM PUBLIC;
SET LOCAL search_path TO plantcare, pg_catalog;

CREATE TABLE profiles (
    id uuid PRIMARY KEY, -- UUID do dịch vụ xác thực cấp
    display_name text NOT NULL CHECK (btrim(display_name) <> ''),
    avatar_key text,
    timezone text NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE plant_species (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    scientific_name text NOT NULL CHECK (btrim(scientific_name) <> ''),
    common_name text,
    light_guide text,
    soil_guide text,
    water_guide text,
    temperature_guide text,
    fertilizer_guide text,
    watering_days integer CHECK (watering_days > 0),
    fertilizing_days integer CHECK (fertilizing_days > 0),
    care_source text
);
CREATE UNIQUE INDEX species_scientific_name ON plant_species (lower(btrim(scientific_name)));

CREATE TABLE plants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
    species_id uuid REFERENCES plant_species,
    nickname text NOT NULL CHECK (btrim(nickname) <> ''),
    cover_image_key text,
    environment text NOT NULL DEFAULT 'unknown'
        CHECK (environment IN ('indoor','outdoor','unknown')),
    region_name text,
    latitude numeric(7,4) CHECK (latitude BETWEEN -90 AND 90),
    longitude numeric(7,4) CHECK (longitude BETWEEN -180 AND 180),
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((latitude IS NULL) = (longitude IS NULL)),
    UNIQUE (owner_id, id)
);
CREATE INDEX plants_garden ON plants (owner_id, created_at DESC);

CREATE TABLE scans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
    request_id uuid NOT NULL, -- client giữ nguyên khi thử lại cùng lần gửi
    plant_id uuid, -- có thể chưa gắn cây khi ảnh chưa xác định được
    image_key text NOT NULL CHECK (btrim(image_key) <> ''),
    mode text NOT NULL CHECK (mode IN ('identify','diagnose','both')),
    source text NOT NULL CHECK (btrim(source) <> ''), -- tên nhà cung cấp hoặc bộ mẫu
    is_mock boolean NOT NULL,
    scanned_at timestamptz NOT NULL DEFAULT now(),
    species_id uuid REFERENCES plant_species,
    reported_species_name text, -- tên tại thời điểm quét
    species_confidence numeric CHECK (species_confidence BETWEEN 0 AND 1),
    health_status text NOT NULL CHECK (health_status IN ('healthy','suspected','unknown','not_assessed')),
    UNIQUE (owner_id, request_id),
    FOREIGN KEY (owner_id, plant_id) REFERENCES plants (owner_id, id) ON DELETE CASCADE
);
CREATE INDEX scans_timeline ON scans (plant_id, scanned_at DESC, id DESC);
CREATE INDEX scans_owner ON scans (owner_id, scanned_at DESC);

CREATE TABLE diseases (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    display_name text NOT NULL
);

CREATE TABLE scan_findings (
    scan_id uuid NOT NULL REFERENCES scans ON DELETE CASCADE,
    position integer NOT NULL CHECK (position > 0),
    disease_id uuid REFERENCES diseases, -- nhãn ngoài danh mục vẫn lưu được
    reported_name text NOT NULL,
    confidence numeric CHECK (confidence BETWEEN 0 AND 1),
    symptoms text,
    possible_cause text,
    treatment_steps text[] NOT NULL DEFAULT '{}',
    guidance_source text,
    PRIMARY KEY (scan_id, position)
);

CREATE TABLE care_schedules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plant_id uuid NOT NULL REFERENCES plants ON DELETE CASCADE,
    kind text NOT NULL CHECK (kind IN ('water','fertilize')),
    interval_days integer NOT NULL CHECK (interval_days > 0),
    local_time time NOT NULL,
    enabled boolean NOT NULL DEFAULT true,
    UNIQUE (plant_id, kind),
    UNIQUE (id, plant_id, kind)
);

CREATE TABLE care_tasks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id uuid NOT NULL,
    plant_id uuid NOT NULL,
    kind text NOT NULL,
    original_due_at timestamptz NOT NULL,
    due_at timestamptz NOT NULL, -- hạn thực tế sau khi dời lịch
    state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','done','skipped')),
    adjustment_reason text,
    weather_snapshot jsonb CHECK (jsonb_typeof(weather_snapshot) = 'object'),
    FOREIGN KEY (schedule_id, plant_id, kind) REFERENCES care_schedules (id, plant_id, kind) ON DELETE CASCADE,
    UNIQUE (id, plant_id, kind),
    UNIQUE (schedule_id, original_due_at)
);
CREATE INDEX tasks_due ON care_tasks (due_at, schedule_id) WHERE state = 'pending';

CREATE TABLE care_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plant_id uuid NOT NULL REFERENCES plants ON DELETE CASCADE,
    request_id uuid NOT NULL,
    task_id uuid UNIQUE,
    kind text NOT NULL CHECK (kind IN ('water','fertilize','treat','note')),
    performed_at timestamptz NOT NULL DEFAULT now(),
    note text,
    FOREIGN KEY (task_id, plant_id, kind) REFERENCES care_tasks (id, plant_id, kind) ON DELETE CASCADE,
    UNIQUE (plant_id, request_id)
);
CREATE INDEX logs_timeline ON care_logs (plant_id, performed_at DESC);

COMMIT;
