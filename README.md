# SQL_Project_ALX-
# Maji Ndogo: From Analysis to Action (Part 1)

This repository contains **Part 1** of the **Maji Ndogo** SQL project (ALX data analytics). In this first phase, we start exploring a real-world database (≈60,000 records) and begin uncovering patterns, inconsistencies, and early “secrets” hidden in the data — with more discoveries coming in the next parts. 

## Project Goal

Use SQL (MySQL) to explore the survey database, understand the data structure, and identify key issues related to **water access, visit behavior, water source quality, and pollution**.

> ✅ This is only **Part 1** — there are **many other secrets** we still need to reveal with the data in the upcoming parts.

---

## What’s Covered in Part 1

### 1) Get to know the database

* Use the embedded data dictionary to understand columns and meanings

### 2) Dive into water sources

* Identify the table that stores water source info
* Retrieve **unique water source types** (e.g., shared taps, rivers, wells, home taps)

### 3) Unpack visits to water sources

* Explore the `visits` logbook (locations, source IDs, queue times, timestamps, staff)
* Identify extreme queue times (e.g., `time_in_queue > 500`)
* Link `visits` to `water_source` using `source_id` to understand *which sources create long queues*

### 4) Assess water source quality

* Explore water quality scoring provided by field surveyors
* Validate assumptions about repeat visits and identify suspicious patterns (data quality checks)

### 5) Investigate pollution issues (Wells)

* Explore well pollution test records (biological + chemical contamination)
* Detect inconsistencies where:

  * `results = 'Clean'` but `biological > 0.01` (unsafe misclassification)
  * Descriptions incorrectly start with `"Clean ..."` even when contamination exists
* Clean the dataset by:

  * Removing `"Clean "` from contaminated descriptions
  * Updating misclassified results to `Contaminated: Biological` when `biological > 0.01`

---

## Tech Stack

* **MySQL**
* SQL queries for exploration, joins, filtering, and data cleaning

---

## Key Takeaway (Part 1)

Real-world data can contain **human errors** (mis-typed notes, wrong classifications, inconsistent rules). In Part 1, we start building reliable foundations by validating data using **actual values**, not just text descriptions.

---

## Credits

ALX Africa  
