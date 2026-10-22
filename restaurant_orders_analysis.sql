-- =====================================================================
-- Restaurant Orders Analysis (MySQL)
-- Data: menu_items.csv (32 dishes) + order_details.csv (12,234 order lines)
-- Goal: understand which menu items do well or badly, and what the
--       top customers buy, to guide menu decisions.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Setup: create the database and load both CSV files
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS restaurant_orders;
CREATE DATABASE restaurant_orders;
USE restaurant_orders;

-- Allows LOAD DATA LOCAL INFILE (also tick "OPT_LOCAL_INFILE=1" in the
-- connection's Advanced settings in MySQL Workbench if needed)
SET GLOBAL local_infile = 1;

CREATE TABLE menu_items (
    menu_item_id INT PRIMARY KEY,
    item_name    VARCHAR(50),
    category     VARCHAR(20),
    price        DECIMAL(5, 2)
);

CREATE TABLE order_details (
    order_details_id INT PRIMARY KEY,
    order_id         INT,
    order_date       DATE,
    order_time       TIME,
    item_id          INT
);

-- Adjust the paths to where the CSV files are on your computer.
-- The files use Windows line endings ('\r\n'). If a file loads as one
-- row or the last column looks wrong, try '\n' instead.
LOAD DATA LOCAL INFILE 'C:/path/to/menu_items.csv'
INTO TABLE menu_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- The CSV stores dates as 1/1/23, times as 11:38:36 AM, and missing items
-- as the text "NULL". Each value is read into a variable and converted
-- while loading, so dates, times and missing items are stored correctly.
LOAD DATA LOCAL INFILE 'C:/path/to/order_details.csv'
INTO TABLE order_details
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(order_details_id, order_id, @order_date, @order_time, @item_id)
SET order_date = STR_TO_DATE(@order_date, '%c/%e/%y'),
    order_time = STR_TO_DATE(@order_time, '%l:%i:%s %p'),
    item_id    = IF(@item_id IS NULL OR TRIM(@item_id) IN ('', 'NULL'), NULL, @item_id);

-- Checks: 32 menu items, 12,234 order lines, no missing dates or times
SELECT COUNT(*) AS menu_items FROM menu_items;

SELECT
    COUNT(*)                                        AS order_lines,
    SUM(order_date IS NULL)                         AS missing_dates,
    SUM(order_time IS NULL)                         AS missing_times,
    SUM(item_id IS NULL)                            AS lines_without_item
FROM order_details;

-- ---------------------------------------------------------------------
-- 1. Explore the menu
-- ---------------------------------------------------------------------

-- 1a. Size of the menu and price range
SELECT
    COUNT(*)             AS total_items,
    ROUND(AVG(price), 2) AS avg_price,
    MIN(price)           AS cheapest,
    MAX(price)           AS most_expensive
FROM menu_items;

-- 1b. Cheapest and most expensive dishes (all ties included)
SELECT item_name, category, price
FROM menu_items
WHERE price = (SELECT MIN(price) FROM menu_items)
   OR price = (SELECT MAX(price) FROM menu_items)
ORDER BY price;

-- 1c. Dishes and average price per category
SELECT
    category,
    COUNT(*)             AS num_items,
    ROUND(AVG(price), 2) AS avg_price,
    MIN(price)           AS min_price,
    MAX(price)           AS max_price
FROM menu_items
GROUP BY category
ORDER BY avg_price DESC;

-- ---------------------------------------------------------------------
-- 2. Explore the orders
-- ---------------------------------------------------------------------

-- 2a. Period covered, number of orders, items ordered and revenue
SELECT
    MIN(od.order_date)          AS first_day,
    MAX(od.order_date)          AS last_day,
    COUNT(DISTINCT od.order_id) AS total_orders,
    COUNT(od.item_id)           AS items_ordered,
    SUM(mi.price)               AS total_revenue
FROM order_details od
LEFT JOIN menu_items mi ON mi.menu_item_id = od.item_id;

-- 2b. Average number of items per order
SELECT ROUND(AVG(items), 2) AS avg_items_per_order
FROM (
    SELECT order_id, COUNT(item_id) AS items
    FROM order_details
    GROUP BY order_id
) AS per_order;

-- 2c. Orders with the most items, and how many orders have more than 12
SELECT order_id, COUNT(item_id) AS num_items
FROM order_details
GROUP BY order_id
ORDER BY num_items DESC
LIMIT 5;

SELECT COUNT(*) AS orders_over_12_items
FROM (
    SELECT order_id
    FROM order_details
    GROUP BY order_id
    HAVING COUNT(item_id) > 12
) AS big_orders;

-- 2d. Busiest days of the week and hours of the day
SELECT DAYNAME(order_date) AS day_of_week, COUNT(DISTINCT order_id) AS orders
FROM order_details
GROUP BY day_of_week, DAYOFWEEK(order_date)
ORDER BY DAYOFWEEK(order_date);

SELECT HOUR(order_time) AS hour_of_day, COUNT(DISTINCT order_id) AS orders
FROM order_details
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 2e. Orders and revenue per month
SELECT
    DATE_FORMAT(od.order_date, '%Y-%m') AS month,
    COUNT(DISTINCT od.order_id)         AS orders,
    SUM(mi.price)                       AS revenue
FROM order_details od
JOIN menu_items mi ON mi.menu_item_id = od.item_id
GROUP BY month
ORDER BY month;

-- ---------------------------------------------------------------------
-- 3. Customer behaviour: what sells, and what the best orders contain
-- ---------------------------------------------------------------------

-- One combined view: each order line with its dish, category and price.
-- LEFT JOIN keeps order lines without an item, so nothing is lost.
CREATE OR REPLACE VIEW order_lines AS
SELECT
    od.order_details_id,
    od.order_id,
    od.order_date,
    od.order_time,
    mi.item_name,
    mi.category,
    mi.price
FROM order_details od
LEFT JOIN menu_items mi ON mi.menu_item_id = od.item_id;

-- 3a. Most and least ordered dishes
SELECT item_name, category, COUNT(*) AS times_ordered, SUM(price) AS revenue
FROM order_lines
WHERE item_name IS NOT NULL
GROUP BY item_name, category
ORDER BY times_ordered DESC;           -- most ordered first

-- 3b. Orders and revenue per category
SELECT
    category,
    COUNT(*)   AS items_ordered,
    SUM(price) AS revenue,
    ROUND(SUM(price) * 100 / SUM(SUM(price)) OVER (), 1) AS pct_revenue
FROM order_lines
WHERE category IS NOT NULL
GROUP BY category
ORDER BY revenue DESC;

-- 3c. Top 5 orders by amount spent
SELECT order_id, COUNT(item_name) AS items, SUM(price) AS total_spent
FROM order_lines
GROUP BY order_id
ORDER BY total_spent DESC
LIMIT 5;

-- 3d. What the top 5 orders contain, by category
WITH top_orders AS (
    SELECT order_id
    FROM order_lines
    GROUP BY order_id
    ORDER BY SUM(price) DESC
    LIMIT 5
)
SELECT
    ol.category,
    COUNT(*)      AS items,
    SUM(ol.price) AS spent,
    ROUND(SUM(ol.price) * 100 / SUM(SUM(ol.price)) OVER (), 1) AS pct_spent
FROM order_lines ol
JOIN top_orders t ON t.order_id = ol.order_id
WHERE ol.category IS NOT NULL
GROUP BY ol.category
ORDER BY items DESC;

-- 3e. Same breakdown for each of the top 5 orders
WITH top_orders AS (
    SELECT order_id
    FROM order_lines
    GROUP BY order_id
    ORDER BY SUM(price) DESC
    LIMIT 5
)
SELECT ol.order_id, ol.category, COUNT(*) AS items
FROM order_lines ol
JOIN top_orders t ON t.order_id = ol.order_id
WHERE ol.category IS NOT NULL
GROUP BY ol.order_id, ol.category
ORDER BY ol.order_id, items DESC;
