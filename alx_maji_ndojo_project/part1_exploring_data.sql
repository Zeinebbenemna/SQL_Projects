-- =====================================================================
-- Maji Ndogo – Part 1: Beginning our data-driven journey
-- Database: md_water_services (MySQL), ~60,000 records
-- =====================================================================

USE md_water_services;

-- ---------------------------------------------------------------------
-- 1. Get to know the database
-- ---------------------------------------------------------------------
SHOW TABLES;

-- ---------------------------------------------------------------------
-- 2. Dive into the water sources
-- ---------------------------------------------------------------------

-- Unique types of water sources
SELECT DISTINCT type_of_water_source
FROM water_source;

-- ---------------------------------------------------------------------
-- 3. Unpack the visits to water sources
-- ---------------------------------------------------------------------

-- Check the format of the time_in_queue column
SELECT time_in_queue
FROM visits
LIMIT 10;

-- Visits where people queued for more than 500 minutes
SELECT *
FROM visits
WHERE time_in_queue > 500;

-- Which types of water source have queues longer than 500 minutes?
SELECT
    v.source_id,
    v.time_in_queue,
    ws.type_of_water_source,
    ws.number_of_people_served
FROM visits v
JOIN water_source ws ON v.source_id = ws.source_id
WHERE v.time_in_queue > 500;

-- Which types of water source have no queue at all?
SELECT
    v.source_id,
    v.time_in_queue,
    ws.type_of_water_source,
    ws.number_of_people_served
FROM visits v
JOIN water_source ws ON v.source_id = ws.source_id
WHERE v.time_in_queue = 0;

-- ---------------------------------------------------------------------
-- 4. Assess the quality of water sources
-- ---------------------------------------------------------------------

-- Home taps get a score of 10 and should only be visited once.
-- Records with a score of 10 on a second visit point to surveyor mistakes.
-- Expected: 218 rows
SELECT *
FROM water_quality
WHERE subjective_quality_score = 10
  AND visit_count = 2;

-- ---------------------------------------------------------------------
-- 5. Investigate pollution issues
-- ---------------------------------------------------------------------

-- Wells marked "Clean" although biological contamination is above 0.01
SELECT *
FROM well_pollution
WHERE biological > 0.01
  AND results = 'Clean'
ORDER BY biological DESC;

-- The cause: descriptions starting with "Clean" followed by a contaminant
SELECT DISTINCT description
FROM well_pollution
WHERE description LIKE 'Clean_%';

-- ---------------------------------------------------------------------
-- 6. Correct the pollution data
-- ---------------------------------------------------------------------

-- 6a. Back up the table before changing anything
DROP TABLE IF EXISTS well_pollution_copy;

CREATE TABLE well_pollution_copy AS
SELECT * FROM well_pollution;

-- MySQL Workbench blocks UPDATEs without a key in the WHERE clause
-- ("safe update mode", Error 1175). Turned it off for this session.
SET SQL_SAFE_UPDATES = 0;

-- 6b. Remove the wrong "Clean" from contaminated descriptions
UPDATE well_pollution
SET description = 'Bacteria: E. coli'
WHERE description = 'Clean Bacteria: E. coli';

UPDATE well_pollution
SET description = 'Bacteria: Giardia Lamblia'
WHERE description = 'Clean Bacteria: Giardia Lamblia';

-- 6c. Reclassify wells that were marked Clean but are biologically contaminated
UPDATE well_pollution
SET results = 'Contaminated: Biological'
WHERE biological > 0.01
  AND results = 'Clean';

-- 6d. Check: this should return 0 rows
SELECT *
FROM well_pollution
WHERE description LIKE 'Clean_%'
   OR (results = 'Clean' AND biological > 0.01);


