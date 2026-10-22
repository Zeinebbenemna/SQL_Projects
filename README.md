# 🍽️ Restaurant Orders Analysis – SQL

Analysis of **3 months of orders (Jan–Mar 2023)** at a restaurant with an international menu, to find which dishes perform well or badly and what the best customers order.

**File:** `restaurant_orders_analysis.sql` · **Data:** `data/menu_items.csv` (32 dishes), `data/order_details.csv` (12,234 order lines) – public practice dataset

---

## 🧹 Data preparation

- Created both tables with proper types and keys, and loaded the CSVs with `LOAD DATA`.
- **Fixed a date import problem:** the file stores dates as `1/1/23` and times as `11:38:36 AM`. Loaded directly, **7,294 dates became `0000-00-00`**, the others got the wrong year, and times lost AM/PM. Each value is now converted with `STR_TO_DATE` during the load, so **0 dates or times are missing**.
- Converted the text "NULL" into real missing values: **137 order lines have no item** and are kept but excluded from item analysis.

---

## 📊 Key findings

**The menu**
- 32 dishes in 4 categories; prices from **$5.00 (Edamame)** to **$19.95 (Shrimp Scampi)**, average $13.29.
- **Italian** is the most expensive category (avg $16.75), **American** the cheapest ($10.07).

**The orders**
- **5,370 orders**, 12,097 items, **$159,218 revenue** over 3 months; 2.25 items per order on average.
- Busiest times: **lunch (12–1 pm)** and **dinner (5–7 pm)**; **Monday** is the busiest day.

**What sells**
- Most ordered: **Hamburger (622)**, Edamame (620), Korean Beef Bowl (588).
- Least ordered: **Chicken Tacos (123)**, Potstickers (205), Cheese Lasagna (207).
- **Asian dishes are ordered most (3,470 items), but Italian brings the most revenue (31%)** because it's more expensive.

**The best customers**
- The top 5 orders each spent **$185–$192**, with 13–14 items.
- **Italian is the largest category in the top orders** (26 of 69 items, 45% of their spending).

**Recommendation:** keep the expensive Italian dishes, which the highest-spending customers buy, and review low performers such as Chicken Tacos and Potstickers.

---

## 🛠️ SQL skills used

`LOAD DATA` with on-the-fly conversion · `STR_TO_DATE` · `LEFT JOIN` · views · CTEs · subqueries · `GROUP BY` / `HAVING` · window functions (`SUM() OVER`) · date and time functions

## ▶️ How to run

Open the script in MySQL Workbench, change the two CSV paths in section 0, and run it top to bottom. It creates its own `restaurant_orders` database. If loading fails with a "local infile" error, enable `OPT_LOCAL_INFILE=1` in the connection's Advanced settings.
