BEGIN;
CREATE TABLE plantcare.reference_images (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    species_id uuid NOT NULL REFERENCES plantcare.plant_species(id),
    provider text NOT NULL CHECK (btrim(provider) <> ''),
    provider_image_id text NOT NULL CHECK (btrim(provider_image_id) <> ''),
    image_url text NOT NULL CHECK (image_url ~ '^https://'),
    thumbnail_url text CHECK (thumbnail_url ~ '^https://'),
    attribution text NOT NULL CHECK (btrim(attribution) <> ''),
    source_url text NOT NULL CHECK (source_url ~ '^https://'),
    license_name text NOT NULL CHECK (btrim(license_name) <> ''),
    license_url text CHECK (license_url ~ '^https://'),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (provider, provider_image_id, species_id),
    UNIQUE (id, species_id)
);
ALTER TABLE plantcare.plants ADD COLUMN reference_image_id uuid;
ALTER TABLE plantcare.plants ADD CONSTRAINT cover_matches_species
    FOREIGN KEY (reference_image_id, species_id)
    REFERENCES plantcare.reference_images(id, species_id);
ALTER TABLE plantcare.plants ADD CONSTRAINT cover_has_species
    CHECK (reference_image_id IS NULL OR species_id IS NOT NULL);
ALTER TABLE plantcare.plants ADD CONSTRAINT cover_single_source
    CHECK (reference_image_id IS NULL OR cover_image_key IS NULL);
CREATE INDEX reference_images_species ON plantcare.reference_images(species_id);
CREATE INDEX plants_species ON plantcare.plants(species_id);
CREATE INDEX plants_reference_image ON plantcare.plants(reference_image_id);
CREATE INDEX scans_species ON plantcare.scans(species_id);
CREATE INDEX findings_disease ON plantcare.scan_findings(disease_id);
CREATE INDEX tasks_schedule ON plantcare.care_tasks(schedule_id);
COMMIT;
