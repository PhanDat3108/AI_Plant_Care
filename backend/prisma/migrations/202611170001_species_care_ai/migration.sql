BEGIN;
ALTER TABLE plantcare.plant_species
  ADD COLUMN care_status text NOT NULL DEFAULT 'missing'
    CHECK (care_status IN ('missing', 'draft', 'verified')),
  ADD COLUMN care_generated_at timestamptz(3),
  ADD COLUMN care_model text,
  ADD COLUMN care_reviewed_at timestamptz(3),
  ADD COLUMN care_reviewed_by uuid,
  ADD CONSTRAINT species_care_reviewed CHECK (care_status <> 'verified' OR care_reviewed_at IS NOT NULL);

-- Preserve old values, but do not declare unreviewed legacy data verified.
UPDATE plantcare.plant_species SET care_status = 'draft'
WHERE watering_days IS NOT NULL OR fertilizing_days IS NOT NULL
   OR water_guide IS NOT NULL OR light_guide IS NOT NULL OR soil_guide IS NOT NULL
   OR temperature_guide IS NOT NULL OR fertilizer_guide IS NOT NULL;

CREATE TABLE plantcare.species_care_drafts (
  species_id uuid PRIMARY KEY REFERENCES plantcare.plant_species ON DELETE CASCADE,
  generation_id uuid NOT NULL UNIQUE,
  scientific_name text NOT NULL CHECK (btrim(scientific_name) <> ''),
  status text NOT NULL CHECK (status IN ('generating', 'draft', 'failed', 'approved', 'rejected')),
  provider text NOT NULL CHECK (provider IN ('gemini', 'demo')),
  model text NOT NULL,
  is_mock boolean NOT NULL,
  source_documents jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(source_documents) = 'array'),
  data jsonb CHECK (jsonb_typeof(data) = 'object'),
  started_at timestamptz(3) NOT NULL,
  generated_at timestamptz(3),
  retry_after timestamptz(3),
  error_code text,
  reviewed_at timestamptz(3),
  reviewed_by uuid,
  review_note text,
  CHECK (is_mock = (provider = 'demo')),
  CHECK (status NOT IN ('draft', 'approved', 'rejected') OR (data IS NOT NULL AND generated_at IS NOT NULL)),
  CHECK (status NOT IN ('approved', 'rejected') OR (reviewed_at IS NOT NULL AND reviewed_by IS NOT NULL)),
  CHECK (status <> 'approved' OR NOT is_mock)
);
REVOKE ALL ON plantcare.species_care_drafts FROM PUBLIC;
COMMIT;
