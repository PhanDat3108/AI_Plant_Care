BEGIN;
ALTER TABLE plantcare.plant_species ADD COLUMN common_name_locale text;
COMMIT;
