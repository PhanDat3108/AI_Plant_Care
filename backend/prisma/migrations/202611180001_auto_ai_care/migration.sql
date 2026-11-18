-- AI output is usable without claiming it has been reviewed by a person.
ALTER TABLE plantcare.plant_species
  DROP CONSTRAINT plant_species_care_status_check,
  ADD CONSTRAINT plant_species_care_status_check
    CHECK (care_status IN ('missing', 'draft', 'ai_suggested', 'verified'));
