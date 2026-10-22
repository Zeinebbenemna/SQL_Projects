-- =====================================================================
-- Global Tech Layoffs (2020–2023): Data Cleaning & Exploratory Analysis
-- Data: layoffs.csv (2,361 rows)
-- Steps:
--   0. Load the raw data
--   1. Back up the raw data
--   2. Remove duplicates
--   3. Standardise text values
--   4. Fix data types (dates, numbers)
--   5. Handle missing values
--   6. Final cleanup and checks
--   7. Exploratory analysis
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Load the raw data
--    Every column is loaded as text first, so nothing is lost or
--    rejected on import. Types are fixed during cleaning.
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS world_layoffs;
CREATE DATABASE world_layoffs;
USE world_layoffs;

SET GLOBAL local_infile = 1;
SET SQL_SAFE_UPDATES = 0;

CREATE TABLE layoffs (
    company               TEXT,
    location              TEXT,
    industry              TEXT,
    total_laid_off        TEXT,
    percentage_laid_off   TEXT,
    `date`                TEXT,
    stage                 TEXT,
    country               TEXT,
    funds_raised_millions TEXT
);

-- Adjust the path. The file uses Windows line endings ('\r\n');
-- try '\n' if it loads as a single row.
LOAD DATA LOCAL INFILE 'C:/path/to/layoffs.csv'
INTO TABLE layoffs
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Check: 2,361 rows expected
SELECT COUNT(*) AS raw_rows FROM layoffs;

-- ---------------------------------------------------------------------
-- 1. Back up the raw data (we never change the original table)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS layoffs_staging;
CREATE TABLE layoffs_staging LIKE layoffs;
INSERT INTO layoffs_staging SELECT * FROM layoffs;

-- ---------------------------------------------------------------------
-- 2. Remove duplicates
-- ---------------------------------------------------------------------

-- 2a. Preview duplicate rows (same values in every column)
WITH duplicate_cte AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY company, location, industry, total_laid_off,
                            percentage_laid_off, `date`, stage, country,
                            funds_raised_millions
           ) AS row_num
    FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;
-- Expected: 5 duplicates

-- 2b. Copy the data with a row number, then delete the extra copies
DROP TABLE IF EXISTS layoffs_clean;
CREATE TABLE layoffs_clean (
    company               TEXT,
    location              TEXT,
    industry              TEXT,
    total_laid_off        TEXT,
    percentage_laid_off   TEXT,
    `date`                TEXT,
    stage                 TEXT,
    country               TEXT,
    funds_raised_millions TEXT,
    row_num               INT
);

INSERT INTO layoffs_clean
SELECT *,
       ROW_NUMBER() OVER (
           PARTITION BY company, location, industry, total_laid_off,
                        percentage_laid_off, `date`, stage, country,
                        funds_raised_millions
       ) AS row_num
FROM layoffs_staging;

DELETE FROM layoffs_clean
WHERE row_num > 1;

-- Check: 2,356 rows left
SELECT COUNT(*) AS rows_after_deduplication FROM layoffs_clean;

-- ---------------------------------------------------------------------
-- 3. Standardise text values
-- ---------------------------------------------------------------------

-- 3a. Remove extra spaces from company names
UPDATE layoffs_clean
SET company = TRIM(company);

-- 3b. One spelling per industry: "Crypto Currency" and "CryptoCurrency" -> "Crypto"
SELECT DISTINCT industry
FROM layoffs_clean
ORDER BY industry;

UPDATE layoffs_clean
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- 3c. One spelling per country: "United States." -> "United States"
UPDATE layoffs_clean
SET country = TRIM(TRAILING '.' FROM country);

SELECT DISTINCT country
FROM layoffs_clean
ORDER BY country;

-- ---------------------------------------------------------------------
-- 4. Fix data types
-- ---------------------------------------------------------------------

-- 4a. The CSV writes missing values as the text "NULL": make them real NULLs
UPDATE layoffs_clean
SET industry              = NULLIF(NULLIF(industry, 'NULL'), ''),
    total_laid_off        = NULLIF(total_laid_off, 'NULL'),
    percentage_laid_off   = NULLIF(percentage_laid_off, 'NULL'),
    `date`                = NULLIF(`date`, 'NULL'),
    stage                 = NULLIF(stage, 'NULL'),
    funds_raised_millions = NULLIF(funds_raised_millions, 'NULL');

-- 4b. Text dates (3/6/2023) -> DATE
UPDATE layoffs_clean
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_clean
    MODIFY COLUMN `date` DATE,
    MODIFY COLUMN total_laid_off INT,
    MODIFY COLUMN percentage_laid_off DECIMAL(5, 4),
    MODIFY COLUMN funds_raised_millions DECIMAL(10, 2);

-- ---------------------------------------------------------------------
-- 5. Handle missing values
-- ---------------------------------------------------------------------

-- 5a. Fill a missing industry from another row of the same company
--     and location (e.g. Airbnb, Carvana, Juul)
SELECT t1.company, t1.location, t1.industry, t2.industry AS industry_found
FROM layoffs_clean t1
JOIN layoffs_clean t2
  ON t1.company = t2.company
 AND t1.location = t2.location
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

UPDATE layoffs_clean t1
JOIN layoffs_clean t2
  ON t1.company = t2.company
 AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Rows still without an industry (no other row to copy from)
SELECT company, location, industry
FROM layoffs_clean
WHERE industry IS NULL;

-- 5b. Rows with no layoff figures at all can't be used for this analysis
SELECT COUNT(*) AS rows_without_layoff_data
FROM layoffs_clean
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

DELETE FROM layoffs_clean
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- ---------------------------------------------------------------------
-- 6. Final cleanup and checks
-- ---------------------------------------------------------------------
ALTER TABLE layoffs_clean
DROP COLUMN row_num;

SELECT
    COUNT(*)                      AS final_rows,
    SUM(`date` IS NULL)           AS missing_dates,
    SUM(industry IS NULL)         AS missing_industry,
    MIN(`date`)                   AS first_date,
    MAX(`date`)                   AS last_date
FROM layoffs_clean;

-- =====================================================================
-- 7. Exploratory analysis
-- =====================================================================

-- 7a. Overview
SELECT
    SUM(total_laid_off)        AS total_laid_off,
    COUNT(DISTINCT company)    AS companies,
    MAX(total_laid_off)        AS largest_single_layoff,
    COUNT(DISTINCT CASE WHEN percentage_laid_off = 1 THEN company END)
                               AS companies_laid_off_100pct
FROM layoffs_clean;

-- 7b. Companies that laid off everyone, by funds raised
SELECT company, industry, country, total_laid_off, funds_raised_millions
FROM layoffs_clean
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC
LIMIT 10;

-- 7c. Top 10 companies by total layoffs
SELECT company, SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
GROUP BY company
ORDER BY total_laid_off DESC
LIMIT 10;

-- 7d. Layoffs by industry
SELECT industry, SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
GROUP BY industry
ORDER BY total_laid_off DESC;

-- 7e. Top 10 countries
SELECT
    country,
    SUM(total_laid_off) AS total_laid_off,
    ROUND(SUM(total_laid_off) * 100 / SUM(SUM(total_laid_off)) OVER (), 1) AS pct_of_total
FROM layoffs_clean
GROUP BY country
ORDER BY total_laid_off DESC
LIMIT 10;

-- 7f. Layoffs per year
SELECT YEAR(`date`) AS year, SUM(total_laid_off) AS total_laid_off
FROM layoffs_clean
WHERE `date` IS NOT NULL
GROUP BY year
ORDER BY year;

-- 7g. Layoffs by company stage
SELECT
    stage,
    SUM(total_laid_off) AS total_laid_off,
    ROUND(SUM(total_laid_off) * 100 / SUM(SUM(total_laid_off)) OVER (), 1) AS pct_of_total
FROM layoffs_clean
GROUP BY stage
ORDER BY total_laid_off DESC;

-- 7h. Monthly layoffs with a running total
WITH monthly AS (
    SELECT DATE_FORMAT(`date`, '%Y-%m') AS month,
           SUM(total_laid_off)          AS laid_off
    FROM layoffs_clean
    WHERE `date` IS NOT NULL
    GROUP BY month
)
SELECT
    month,
    laid_off,
    SUM(laid_off) OVER (ORDER BY month) AS running_total
FROM monthly
ORDER BY month;

-- 7i. Worst months
SELECT DATE_FORMAT(`date`, '%Y-%m') AS month, SUM(total_laid_off) AS laid_off
FROM layoffs_clean
WHERE `date` IS NOT NULL
GROUP BY month
ORDER BY laid_off DESC
LIMIT 5;

-- 7j. Top 5 companies by layoffs each year
WITH company_year AS (
    SELECT company, YEAR(`date`) AS year, SUM(total_laid_off) AS laid_off
    FROM layoffs_clean
    WHERE `date` IS NOT NULL
    GROUP BY company, year
),
ranked AS (
    SELECT *,
           DENSE_RANK() OVER (PARTITION BY year ORDER BY laid_off DESC) AS ranking
    FROM company_year
    WHERE laid_off IS NOT NULL
)
SELECT year, ranking, company, laid_off
FROM ranked
WHERE ranking <= 5
ORDER BY year, ranking;
