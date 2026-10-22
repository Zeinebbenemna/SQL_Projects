-- =====================================================================
-- Maji Ndogo – Part 2: Clustering data to unveil the water crisis
-- Database: md_water_services (MySQL)
-- =====================================================================

USE md_water_services;

-- MySQL Workbench blocks UPDATEs without a key in the WHERE clause
-- ("safe update mode", Error 1175). Turned it off for this session.
SET SQL_SAFE_UPDATES = 0;

-- ---------------------------------------------------------------------
-- 1. Cleaning employee data
-- ---------------------------------------------------------------------

-- 1a. Build email addresses: first.last@ndogowater.gov
SELECT
    CONCAT(LOWER(REPLACE(employee_name, ' ', '.')), '@ndogowater.gov') AS new_email
FROM employee;

-- Save them in the table (the original script only displayed them)
UPDATE employee
SET email = CONCAT(LOWER(REPLACE(employee_name, ' ', '.')), '@ndogowater.gov');

-- 1b. Phone numbers have a trailing space (13 characters instead of 12)
SELECT LENGTH(phone_number) AS phone_length
FROM employee;

UPDATE employee
SET phone_number = TRIM(phone_number)
WHERE LENGTH(phone_number) = 13;

-- Check: every number should now be 12 characters
SELECT LENGTH(phone_number) AS phone_length, COUNT(*) AS employees
FROM employee
GROUP BY LENGTH(phone_number);

-- ---------------------------------------------------------------------
-- 2. Honouring the workers: top 3 field surveyors by number of visits
-- ---------------------------------------------------------------------
SELECT
    e.assigned_employee_id,
    e.employee_name,
    COUNT(v.record_id) AS number_of_visits
FROM employee e
JOIN visits v ON e.assigned_employee_id = v.assigned_employee_id
GROUP BY e.assigned_employee_id, e.employee_name
ORDER BY number_of_visits DESC          -- DESC = most visits first 
LIMIT 3;

-- ---------------------------------------------------------------------
-- 3. Where do our employees live?
-- ---------------------------------------------------------------------
SELECT town_name, COUNT(assigned_employee_id) AS number_of_employees
FROM employee
GROUP BY town_name
ORDER BY number_of_employees DESC;

-- Contact details of the top 3 surveyors (to congratulate them)
SELECT employee_name, email, phone_number
FROM employee
WHERE assigned_employee_id IN (
    SELECT assigned_employee_id
    FROM (
        SELECT assigned_employee_id, COUNT(record_id) AS number_of_visits
        FROM visits
        GROUP BY assigned_employee_id
        ORDER BY number_of_visits DESC
        LIMIT 3
    ) AS top_3
);

-- ---------------------------------------------------------------------
-- 4. Analysing locations
--    The location table has one row per water source location, so we
--    count there. (Joining visits counted repeat visits several times.)
-- ---------------------------------------------------------------------

-- 4a. Sources per town
SELECT town_name, COUNT(*) AS records_per_town
FROM location
GROUP BY town_name
ORDER BY records_per_town DESC;

-- 4b. Sources per province
SELECT province_name, COUNT(*) AS records_per_province
FROM location
GROUP BY province_name
ORDER BY records_per_province DESC;

-- 4c. Sources per town within each province
SELECT province_name, town_name, COUNT(*) AS records_per_town
FROM location
GROUP BY province_name, town_name
ORDER BY province_name, records_per_town DESC;

-- 4d. Rural vs urban sources, with percentages calculated from the data
SELECT
    location_type,
    COUNT(*) AS num_sources,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 0) AS pct_sources
FROM location
GROUP BY location_type;


-- ---------------------------------------------------------------------
-- 5. Diving into the water sources
-- ---------------------------------------------------------------------

-- 5a. Total number of people surveyed
SELECT SUM(number_of_people_served) AS total_people_surveyed
FROM water_source;

-- 5b. Number of sources of each type
SELECT type_of_water_source, COUNT(*) AS number_of_sources
FROM water_source
GROUP BY type_of_water_source
ORDER BY number_of_sources DESC;

-- 5c. Average number of people served by one source of each type
SELECT type_of_water_source, ROUND(AVG(number_of_people_served)) AS ave_people_per_source
FROM water_source
GROUP BY type_of_water_source
ORDER BY ave_people_per_source DESC;

-- 5d. Total people served by each type, and as a % of all people
SELECT
    type_of_water_source,
    SUM(number_of_people_served) AS population_served,
    ROUND(SUM(number_of_people_served) * 100.0
          / (SELECT SUM(number_of_people_served) FROM water_source), 0) AS percentage_people_per_source
FROM water_source
GROUP BY type_of_water_source
ORDER BY population_served DESC;

-- ---------------------------------------------------------------------
-- 6. Start of a solution: what to fix first
-- ---------------------------------------------------------------------

-- 6a. Rank source types by people served (tap_in_home is already the
--     best option, so it is excluded)
SELECT
    type_of_water_source,
    SUM(number_of_people_served) AS people_served,
    RANK() OVER (ORDER BY SUM(number_of_people_served) DESC) AS rank_by_population
FROM water_source
WHERE type_of_water_source <> 'tap_in_home'
GROUP BY type_of_water_source;

-- 6b. Priority list of individual sources within each type
SELECT
    source_id,
    type_of_water_source,
    number_of_people_served,
    RANK() OVER (PARTITION BY type_of_water_source
                 ORDER BY number_of_people_served DESC) AS priority_rank
FROM water_source
WHERE type_of_water_source <> 'tap_in_home'
ORDER BY type_of_water_source, priority_rank;

-- ---------------------------------------------------------------------
-- 7. Analysing queues
-- ---------------------------------------------------------------------

-- 7a. How long did the survey take? 
SELECT DATEDIFF(MAX(time_of_record), MIN(time_of_record)) AS survey_length_days
FROM visits;

-- 7b. Average queue time, ignoring sources with no queue 
SELECT ROUND(AVG(NULLIF(time_in_queue, 0))) AS avg_queue_time
FROM visits;

-- 7c. Average queue time per day of the week
SELECT
    DAYNAME(time_of_record) AS day_of_week,
    ROUND(AVG(NULLIF(time_in_queue, 0))) AS avg_queue_time
FROM visits
GROUP BY day_of_week, DAYOFWEEK(time_of_record)
ORDER BY DAYOFWEEK(time_of_record);

-- 7d. Average queue time per hour of the day
SELECT
    TIME_FORMAT(TIME(time_of_record), '%H:00') AS hour_of_day,
    ROUND(AVG(NULLIF(time_in_queue, 0))) AS avg_queue_time
FROM visits
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 7e. Pivot table: average queue time for each hour of each day
SELECT
    TIME_FORMAT(TIME(time_of_record), '%H:00') AS hour_of_day,
    ROUND(AVG(CASE WHEN DAYNAME(time_of_record) = 'Sunday'    THEN time_in_queue END), 0) AS Sunday,
    ROUND(AVG(CASE WHEN DAYNAME(time_of_record) = 'Monday'    THEN time_in_queue END), 0) AS Monday,
    ROUND(AVG(CASE WHEN DAYNAME(time_of_record) = 'Tuesday'   THEN time_in_queue END), 0) AS Tuesday,
    ROUND(AVG(CASE WHEN DAYNAME(time_of_record) = 'Wednesday' THEN time_in_queue END), 0) AS Wednesday,
    ROUND(AVG(CASE WHEN DAYNAME(time_of_record) = 'Thursday'  THEN time_in_queue END), 0) AS Thursday,
    ROUND(AVG(CASE WHEN DAYNAME(time_of_record) = 'Friday'    THEN time_in_queue END), 0) AS Friday,
    ROUND(AVG(CASE WHEN DAYNAME(time_of_record) = 'Saturday'  THEN time_in_queue END), 0) AS Saturday
FROM visits
WHERE time_in_queue <> 0          -- exclude sources with no queue
GROUP BY hour_of_day
ORDER BY hour_of_day;
