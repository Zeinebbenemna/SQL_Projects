-- =====================================================================
-- Maji Ndogo – Part 3: Weaving the data threads (auditor report)
-- =====================================================================

USE md_water_services;

-- Check the import: expected 1,620
SELECT COUNT(*) AS audited_records
FROM auditor_report;

-- Clean hidden characters (spaces, tabs, line breaks) that can come in
-- with the CSV and stop location_id from matching the other tables.
-- Safe to run more than once.
SET SQL_SAFE_UPDATES = 0;

UPDATE auditor_report
SET location_id = TRIM(REPLACE(REPLACE(REPLACE(location_id, '\r', ''), '\n', ''), '\t', '')),
    statements  = TRIM(REPLACE(REPLACE(statements, '\r', ''), '\n', ''));

-- Check the link with the survey data: expected 1,620
SELECT COUNT(*) AS audited_records_linked
FROM auditor_report ar
JOIN visits v ON ar.location_id = v.location_id
WHERE v.visit_count = 1;

-- ---------------------------------------------------------------------
-- 1. Check that the auditor and the surveyors saw the same type of source
--    Expected result: 0 rows (the original query used "=" and so
--    returned the matching rows instead of the differences)
-- ---------------------------------------------------------------------
SELECT
    ws.source_id,
    v.location_id,
    ws.type_of_water_source  AS surveyor_source,
    ar.type_of_water_source  AS auditor_source,
    v.record_id,
    wq.subjective_quality_score AS surveyor_score,
    ar.true_water_source_score  AS auditor_score
FROM auditor_report ar
JOIN visits v         ON ar.location_id = v.location_id
JOIN water_source ws  ON ws.source_id = v.source_id
JOIN water_quality wq ON wq.record_id = v.record_id
WHERE v.visit_count = 1
  AND ws.type_of_water_source <> ar.type_of_water_source;

-- ---------------------------------------------------------------------
-- 2. Records where the surveyor's quality score differs from the auditor's
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS Incorrect_records;

CREATE VIEW Incorrect_records AS
SELECT
    ar.location_id,
    v.record_id,
    e.employee_name,
    ar.true_water_source_score  AS auditor_score,
    wq.subjective_quality_score AS surveyor_score,
    ar.statements
FROM auditor_report ar
JOIN visits v         ON ar.location_id = v.location_id
JOIN water_quality wq ON v.record_id = wq.record_id
JOIN employee e       ON e.assigned_employee_id = v.assigned_employee_id
WHERE v.visit_count = 1
  AND ar.true_water_source_score <> wq.subjective_quality_score;

SELECT * FROM Incorrect_records;

-- How many audited records were correct vs incorrect?
SELECT
    SUM(ar.true_water_source_score =  wq.subjective_quality_score) AS matching_scores,
    SUM(ar.true_water_source_score <> wq.subjective_quality_score) AS different_scores
FROM auditor_report ar
JOIN visits v         ON ar.location_id = v.location_id
JOIN water_quality wq ON v.record_id = wq.record_id
WHERE v.visit_count = 1;

-- ---------------------------------------------------------------------
-- 3. Employees with more mistakes than average (suspect list)
-- ---------------------------------------------------------------------
WITH error_count AS (
    SELECT employee_name, COUNT(*) AS number_of_mistakes
    FROM Incorrect_records
    GROUP BY employee_name
),
suspect_list AS (
    SELECT employee_name, number_of_mistakes
    FROM error_count
    WHERE number_of_mistakes > (SELECT AVG(number_of_mistakes) FROM error_count)
)
SELECT *
FROM suspect_list
ORDER BY number_of_mistakes DESC;


-- ---------------------------------------------------------------------
-- 4. Evidence: statements mentioning cash
-- ---------------------------------------------------------------------

-- 4a. Cash statements about the suspects
WITH error_count AS (
    SELECT employee_name, COUNT(*) AS number_of_mistakes
    FROM Incorrect_records
    GROUP BY employee_name
),
suspect_list AS (
    SELECT employee_name
    FROM error_count
    WHERE number_of_mistakes > (SELECT AVG(number_of_mistakes) FROM error_count)
)
SELECT employee_name, location_id, statements
FROM Incorrect_records
WHERE employee_name IN (SELECT employee_name FROM suspect_list)
  AND statements LIKE '%cash%';

-- 4b. Same check for everyone else: if this returns 0 rows,
--     only the suspects are linked to cash
WITH error_count AS (
    SELECT employee_name, COUNT(*) AS number_of_mistakes
    FROM Incorrect_records
    GROUP BY employee_name
),
suspect_list AS (
    SELECT employee_name
    FROM error_count
    WHERE number_of_mistakes > (SELECT AVG(number_of_mistakes) FROM error_count)
)
SELECT employee_name, location_id, statements
FROM Incorrect_records
WHERE employee_name NOT IN (SELECT employee_name FROM suspect_list)
  AND statements LIKE '%cash%';
