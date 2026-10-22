# 💧 Maji Ndogo - From Analysis to Action (SQL)

A 4-part SQL investigation of a national water survey (**60,000+ records**) in the fictional country of Maji Ndogo: cleaning the data, measuring the water crisis, uncovering likely corruption in the survey, and turning the findings into a repair plan for engineering teams.

Built during the **ALX Africa Data Analytics program** (ExploreAI case study) with **MySQL**.

---

## 🗂️ The story in 4 parts

| Part | Question | File |
|---|---|---|
| **1. Exploring the data** | Can we trust the data? | `part1_exploring_data.sql` |
| **2. Clustering the data** | How big is the water crisis, and where? | `part2_clustering_data.sql` |
| **3. Auditor report** | Why do some survey scores look wrong? | `part3_auditor_report.sql` |
| **4. Final analysis** | What should be fixed first, and where? | `part4_final_analysis.sql` |

---

## I- Exploring the data - can we trust it?

- Explored the database structure (8 tables: visits, water sources, locations, employees, quality scores, well pollution tests…).
- Checked the data against the survey's own rules: a score of 10 (home tap, no queue) should never need a second visit, yet **218 records** had both, a first sign of unreliable entries.
- Found **64 wells marked "Clean" despite biological contamination**: field staff had relied on descriptions starting with "Clean".
- Fixed the data safely: backup table first, then corrected **38 descriptions** and **reclassified 64 wells** as "Contaminated: Biological", with a final check returning 0 errors.

## II- Clustering the data - the size of the crisis

- Cleaned employee data (generated 56 email addresses, trimmed 56 phone numbers).
- **60%** of water sources are in rural communities.
- **43%** of people use **shared taps**, with an average of **~2,000 people per tap**.
- **31%** have taps at home, but **45% of those are broken** (14% of the population).
- **18%** use wells, and **9%** drink from rivers.
- The survey took **924 days**, and the average queue is **123 minutes**. Queues are longest on **Saturdays** and in the mornings and evenings (pivot table of queue time by day × hour).
- Ranked sources with `RANK()` to prioritise repairs by number of people affected.

> Data caveat spotted: home taps show ~644 people per tap, because surveyors grouped several households into one record. Averages need context before they're reported.

## III- Auditor report - investigating the survey

An independent auditor re-checked **1,620** sources.

- **94%** of scores matched (1,518); **102** did not.
- Linked the 102 incorrect records to the employees who collected them, and isolated those with an above-average number of mistakes: **4 employees** (26, 21, 17 and 7 mistakes).
- **19** citizen statements about these 4 employees mention **cash**, and **none** about anyone else: a strong signal of bribery, to be reported.
- Twist: one of the suspects was also one of the **top 3 surveyors by number of visits**, a reminder that volume is not quality.

## IV- Final analysis - from insights to action

- Built a combined view of sources, locations, queues and pollution results, then pivoted it by province and town.
- **Sokoto** has the highest share of people drinking river water (**21%**), so it's the first target for drilling wells.
- **Amanzi** relies heavily on home taps, but **24%** of its people have broken ones, so it's a priority for infrastructure repairs.
- Created a **`Project_progress` table** for engineering teams: **25,398 sources** to improve, each with an address and a specific action:

| Improvement | Sources |
|---|---|
| Install RO filter (chemically polluted wells) | 7,093 |
| Diagnose local infrastructure (broken home taps) | 5,856 |
| Install UV and RO filter (biologically contaminated wells) | 5,374 |
| Install extra taps nearby (shared taps with queues ≥ 30 min) | 3,696 |
| Drill well (rivers) | 3,379 |

The table has a status column (Backlog → In progress → Complete) restricted with `CHECK`, so teams can report progress in clean data.

---

##  SQL skills used

- **Data cleaning:** `UPDATE`, `TRIM`, `REPLACE`, `LIKE`, backup tables, validation queries
- **Joins:** `INNER` / `LEFT JOIN` across 5-6 tables
- **Aggregation:** `GROUP BY`, `CASE` pivot tables, `NULLIF`
- **Window functions:** `RANK()`, `SUM() OVER ()`
- **CTEs, subqueries, views and temporary tables**
- **Date functions:** `DATEDIFF`, `DAYNAME`, `TIME_FORMAT`
- **Table design:** primary/foreign keys, `DEFAULT`, `CHECK` constraints

---

##  How to run

1. Load the `md_water_services` database provided by ALX into MySQL.
2. Run the files in order, Part 1 → Part 4 (each part relies on the previous one).
3. For Part 3, import `auditor_report.csv` into the `auditor_report` table first (see the notes at the top of the file).

Each file has comments explaining every step and the expected results.

---

## 🙏 Credits

Case study and data: **ALX Africa Data Analytics program** / ExploreAI Academy. All names and data are fictional.
