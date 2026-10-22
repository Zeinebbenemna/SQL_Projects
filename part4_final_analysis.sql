-- =====================================================================
-- Maji Ndogo – Part 4: Charting the course (final analysis)
-- =====================================================================

USE md_water_services;

-- ---------------------------------------------------------------------
-- 1. Combined table: one row per water source (first visit only)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW combined_analysis_table AS   -- OR REPLACE: can be re-run
SELECT
    ws.type_of_water_source   AS source_type,
    l.town_name,
    l.province_name,
    l.location_type,
    ws.number_of_people_served AS people_served,
    v.time_in_queue,
    wp.results
FROM visits v
LEFT JOIN well_pollution wp ON wp.source_id = v.source_id
INNER JOIN location l       ON l.location_id = v.location_id
INNER JOIN water_source ws  ON ws.source_id = v.source_id
WHERE v.visit_count = 1;

-- ---------------------------------------------------------------------
-- 2. % of people served by each source type, per province
-- ---------------------------------------------------------------------
WITH province_totals AS (
    SELECT province_name, SUM(people_served) AS total_ppl_serv
    FROM combined_analysis_table
    GROUP BY province_name
)
SELECT
    ct.province_name,
    ROUND(SUM(CASE WHEN source_type = 'river'              THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv, 0) AS river,
    ROUND(SUM(CASE WHEN source_type = 'shared_tap'         THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv, 0) AS shared_tap,
    ROUND(SUM(CASE WHEN source_type = 'tap_in_home'        THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv, 0) AS tap_in_home,
    ROUND(SUM(CASE WHEN source_type = 'tap_in_home_broken' THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv, 0) AS tap_in_home_broken,
    ROUND(SUM(CASE WHEN source_type = 'well'               THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv, 0) AS well
FROM combined_analysis_table ct
JOIN province_totals pt ON ct.province_name = pt.province_name
GROUP BY ct.province_name, pt.total_ppl_serv
ORDER BY ct.province_name;

-- ---------------------------------------------------------------------
-- 3. Same breakdown per town (province + town, because two provinces
--    have a town called Harare)
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS town_aggregated_water_access;  

CREATE TEMPORARY TABLE town_aggregated_water_access
WITH town_totals AS (
    SELECT province_name, town_name, SUM(people_served) AS total_ppl_serv
    FROM combined_analysis_table
    GROUP BY province_name, town_name
)
SELECT
    ct.province_name,
    ct.town_name,
    ROUND(SUM(CASE WHEN source_type = 'river'              THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv, 0) AS river,
    ROUND(SUM(CASE WHEN source_type = 'shared_tap'         THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv, 0) AS shared_tap,
    ROUND(SUM(CASE WHEN source_type = 'tap_in_home'        THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv, 0) AS tap_in_home,
    ROUND(SUM(CASE WHEN source_type = 'tap_in_home_broken' THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv, 0) AS tap_in_home_broken,
    ROUND(SUM(CASE WHEN source_type = 'well'               THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv, 0) AS well
FROM combined_analysis_table ct
JOIN town_totals tt
  ON ct.province_name = tt.province_name AND ct.town_name = tt.town_name
GROUP BY ct.province_name, ct.town_name, tt.total_ppl_serv
ORDER BY ct.town_name;

-- 3a. Towns that rely most on rivers
SELECT *
FROM town_aggregated_water_access
ORDER BY river DESC;

-- 3b. Share of home taps that are broken, per town (highest first)
SELECT
    province_name,
    town_name,
    ROUND(tap_in_home_broken / NULLIF(tap_in_home_broken + tap_in_home, 0) * 100, 0) AS pct_broken_taps
FROM town_aggregated_water_access
ORDER BY pct_broken_taps DESC;

-- ---------------------------------------------------------------------
-- 4. A practical plan: the Project_progress table for engineering teams
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS Project_progress;

CREATE TABLE Project_progress (
    Project_id         SERIAL PRIMARY KEY,
    source_id          VARCHAR(20) NOT NULL REFERENCES water_source(source_id)
                       ON DELETE CASCADE ON UPDATE CASCADE,
    Address            VARCHAR(50),
    Town               VARCHAR(30),
    Province           VARCHAR(30),
    Source_type        VARCHAR(50),
    Improvement        VARCHAR(50),       -- what the engineers should do
    Source_status      VARCHAR(50) DEFAULT 'Backlog'
                       CHECK (Source_status IN ('Backlog', 'In progress', 'Complete')),
    Date_of_completion DATE,
    Comments           TEXT
);

-- Sources to improve, with the action for each one:
--   river                        -> Drill well
--   well, chemical contamination -> Install RO filter
--   well, biological contam.     -> Install UV and RO filter
--   shared_tap, queue >= 30 min  -> Install FLOOR(queue / 30) taps nearby
--   tap_in_home_broken           -> Diagnose local infrastructure
INSERT INTO Project_progress (source_id, Address, Town, Province, Source_type, Improvement)
SELECT
    ws.source_id,
    l.address,
    l.town_name,
    l.province_name,
    ws.type_of_water_source,
    CASE
        WHEN wp.results = 'Contaminated: Chemical'   THEN 'Install RO filter'
        WHEN wp.results = 'Contaminated: Biological' THEN 'Install UV and RO filter'
        WHEN ws.type_of_water_source = 'river'       THEN 'Drill well'
        WHEN ws.type_of_water_source = 'shared_tap' AND v.time_in_queue >= 30
             THEN CONCAT('Install ', FLOOR(v.time_in_queue / 30), ' taps nearby')
        WHEN ws.type_of_water_source = 'tap_in_home_broken' THEN 'Diagnose local infrastructure'
        ELSE NULL
    END AS Improvement
FROM water_source ws
LEFT JOIN well_pollution wp ON ws.source_id = wp.source_id
INNER JOIN visits v         ON ws.source_id = v.source_id
INNER JOIN location l       ON l.location_id = v.location_id
WHERE v.visit_count = 1
  AND (
        wp.results <> 'Clean'
     OR ws.type_of_water_source IN ('tap_in_home_broken', 'river')
     OR (ws.type_of_water_source = 'shared_tap' AND v.time_in_queue >= 30)
  );

-- Checks: 25,398 rows expected, and no missing improvement
SELECT COUNT(*) AS sources_to_improve FROM Project_progress;
SELECT COUNT(*) AS missing_improvement FROM Project_progress WHERE Improvement IS NULL;

-- Work plan per improvement type
SELECT Improvement, COUNT(*) AS number_of_sources
FROM Project_progress
GROUP BY Improvement
ORDER BY number_of_sources DESC;
