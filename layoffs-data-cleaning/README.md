# 🧹 Global Tech Layoffs (2020-2023) - SQL Data Cleaning & Analysis

Cleaning a messy public dataset of **2,361 layoff events** with MySQL, then exploring who was hit hardest, when, and where.

**File:** `layoffs_cleaning_and_analysis.sql` · **Data:** `data/layoffs.csv` (public practice dataset)

---

## 🧽 Part 1 - Data cleaning

| Step | What was done | Result |
|---|---|---|
| Backup | Worked on a copy (`layoffs_staging`); the raw table is never modified | - |
| Duplicates | Flagged with `ROW_NUMBER()` over all columns, then deleted | **5 duplicates removed** (2,361 → 2,356) |
| Text | Trimmed company names; merged "Crypto Currency" / "CryptoCurrency" into **Crypto**; fixed "United States." | 1 spelling per industry and country |
| Missing values as text | Converted the text "NULL" into real `NULL`s | Statistics ignore missing values correctly |
| Data types | Text dates (`3/6/2023`) → `DATE`; layoffs → `INT`; percentages and funds → `DECIMAL` | Dates and numbers usable for analysis |
| Missing industries | Filled from another row of the same company and location with a self-join | 1 row left that can't be filled |
| Unusable rows | Removed rows with no layoff number **and** no percentage | **361 rows removed** |

**Final clean table: 1,995 rows**, from March 2020 to March 2023, with row-count checks along the way.

---

## 📊 Part 2 - Exploratory analysis

- **383,659 people** laid off across **1,628 companies**.
- **2022 was the worst year (160,661)**, but **2023 reached 125,677 in just over two months**, with **January 2023 the worst month on record (84,714)**.
- Biggest totals: **Amazon (18,150)**, Google (12,000), Meta (11,000), Salesforce (10,090), Microsoft (10,000).
- **Post-IPO companies account for 53%** of all layoffs.
- Most affected industries: **Consumer** and **Retail**; most affected country by far: the **United States (67%)**, then India.
- **115 companies laid off 100% of their staff**, including some that had raised large sums (Britishvolt $2.4B, Quibi $1.8B).

Techniques: rolling monthly totals with `SUM() OVER`, top 5 companies per year with `DENSE_RANK()`, CTEs.

---

## 🛠️ SQL skills used

`LOAD DATA` · `ROW_NUMBER()` / `DENSE_RANK()` · CTEs · self-join `UPDATE` · `TRIM` / `LIKE` / `NULLIF` · `STR_TO_DATE` · `ALTER TABLE … MODIFY` · window functions · aggregation
