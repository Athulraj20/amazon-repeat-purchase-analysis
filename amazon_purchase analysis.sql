create DATABASE amazon_purchase;


use amazon_purchase;

CREATE TABLE amazon_purchase(
    purchase_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
order_date DATE,
unit_price DECIMAL(12, 2),
quantity INT,
shipping_state VARCHAR(200),
product_title TEXT,
product_code VARCHAR(100),
category VARCHAR(255),
Customer_id VARCHAR(100),
INDEX idx_customer_date (customer_id,order_date)
) DEFAULT CHARACTER SET utf8mb4;

LOAD DATA LOCAL INFILE
    'C:/Users/abinr/Documents/Codex/2026-11-25/ne/outputs/amazon-purchases.csv'
INTO TABLE amazon_purchase
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    @order_date,
    @unit_price,
    @quantity,
    shipping_state,
    product_title,
    product_code,
    category,
    @customer_id
)
SET order_date = NULLIF(TRIM(@order_date), ''),
    unit_price = NULLIF(TRIM(@unit_price), ''),
    quantity = NULLIF(TRIM(@quantity), ''),
    customer_id = NULLIF(TRIM(REPLACE(@customer_id, CHAR(13), '')), '');
SHOW WARNINGS LIMIT 20;

SET GLOBAL local_infile = ON;
SHOW GLOBAL VARIABLES LIKE 'local_infile';

SELECT count(*)  FROM amazon_purchase;

USE amazon_purchase;

LOAD DATA LOCAL INFILE
    'C:/Users/abinr/Documents/Codex/2026-11-25/ne/outputs/amazon-purchases.csv'
INTO TABLE amazon_purchase
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    @order_date,
    @unit_price,
    @quantity,
    shipping_state,
    product_title,
    product_code,
    category,
    @customer_id
)
SET order_date = NULLIF(TRIM(@order_date), ''),
    unit_price = NULLIF(TRIM(@unit_price), ''),
    quantity = NULLIF(TRIM(@quantity), ''),
    customer_id = NULLIF(TRIM(REPLACE(@customer_id, CHAR(13), '')), '');

    SHOW WARNINGS LIMIT 10;

SELECT COUNT(*) AS imported_rows,
       COUNT(DISTINCT customer_id) AS shoppers,
       MIN(order_date) AS first_purchase,
       MAX(order_date) AS last_purchase
FROM amazon_purchase;
SELECT
    YEAR(order_date) AS purchase_year,
    COUNT(*) AS purchase_lines,
    COUNT(DISTINCT customer_id) AS shoppers,
    MIN(order_date) AS first_date,
    MAX(order_date) AS last_date
FROM amazon_purchase
GROUP BY YEAR(order_date)
ORDER BY purchase_year;

WITH purchase_days AS (
    SELECT DISTINCT customer_id, order_date
    FROM amazon_purchase
    WHERE customer_id IS NOT NULL
      AND order_date BETWEEN '2018-01-01' AND '2022-12-31'
),
purchase_sequence AS (
    SELECT
        customer_id,
        order_date,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id ORDER BY order_date
        ) AS purchase_day_number,
        LEAD(order_date) OVER (
            PARTITION BY customer_id ORDER BY order_date
        ) AS next_purchase_date
    FROM purchase_days
),
eligible_shoppers AS (
    SELECT
        customer_id,
        DATEDIFF(next_purchase_date, order_date) AS days_to_return
    FROM purchase_sequence
    WHERE purchase_day_number = 1
      AND order_date <= DATE_SUB('2022-12-31', INTERVAL 90 DAY)
)
SELECT
    COUNT(*) AS eligible_shoppers,
    ROUND(100 * AVG(CASE WHEN days_to_return <= 30 THEN 1 ELSE 0 END), 2)
        AS repeat_within_30_days_pct,
    ROUND(100 * AVG(CASE WHEN days_to_return <= 60 THEN 1 ELSE 0 END), 2)
        AS repeat_within_60_days_pct,
    ROUND(100 * AVG(CASE WHEN days_to_return <= 90 THEN 1 ELSE 0 END), 2)
        AS repeat_within_90_days_pct
FROM eligible_shoppers;

WITH purchase_days AS (
    SELECT DISTINCT customer_id, order_date
    FROM amazon_purchase.amazon_purchase
    WHERE customer_id IS NOT NULL
      AND order_date BETWEEN '2018-01-01' AND '2022-12-31'
),
purchase_sequence AS (
    SELECT
        customer_id,
        order_date,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id ORDER BY order_date
        ) AS purchase_day_number,
        LEAD(order_date) OVER (
            PARTITION BY customer_id ORDER BY order_date
        ) AS next_purchase_date
    FROM purchase_days
),
eligible_shoppers AS (
    SELECT DATEDIFF(next_purchase_date, order_date) AS days_to_return
    FROM purchase_sequence
    WHERE purchase_day_number = 1
      AND order_date <= DATE_SUB('2022-12-31', INTERVAL 90 DAY)
)
SELECT
    COUNT(*) AS eligible_shoppers,
    ROUND(100 * AVG(CASE WHEN days_to_return BETWEEN 1 AND 30 THEN 1 ELSE 0 END), 2)
        AS repeat_within_30_days_pct,
    ROUND(100 * AVG(CASE WHEN days_to_return BETWEEN 1 AND 60 THEN 1 ELSE 0 END), 2)
        AS repeat_within_60_days_pct,
    ROUND(100 * AVG(CASE WHEN days_to_return BETWEEN 1 AND 90 THEN 1 ELSE 0 END), 2)
        AS repeat_within_90_days_pct
FROM eligible_shoppers;
WITH purchase_days AS (
    SELECT DISTINCT customer_id, order_date
    FROM amazon_purchase.amazon_purchase
    WHERE customer_id IS NOT NULL
      AND order_date BETWEEN '2018-01-01' AND '2022-12-31'
),
ranked AS (
    SELECT
        customer_id,
        order_date,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id ORDER BY order_date
        ) AS purchase_day_number,
        LEAD(order_date) OVER (
            PARTITION BY customer_id ORDER BY order_date
        ) AS next_purchase_date
    FROM purchase_days
)
SELECT
    ROUND(100 * AVG(
        CASE WHEN DATEDIFF(next_purchase_date, order_date) BETWEEN 1 AND 90
             THEN 1 ELSE 0 END
    ), 2) AS repeat_within_90_days_pct
FROM ranked
WHERE purchase_day_number = 1
  AND order_date <= '2022-10-02';

  WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_purchase_date
    FROM amazon_purchase.amazon_purchase
    WHERE customer_id IS NOT NULL
      AND order_date BETWEEN '2018-01-01' AND '2022-12-31'
    GROUP BY customer_id
    HAVING MIN(order_date) <= '2022-10-02'
),
shopper_spend AS (
    SELECT
        f.customer_id,
        COUNT(p.order_date) AS repeat_purchase_lines,
        SUM(p.unit_price * p.quantity) AS recorded_spend,
        SUM(CASE
            WHEN p.order_date IS NOT NULL
             AND (p.unit_price IS NULL OR p.quantity IS NULL)
            THEN 1 ELSE 0
        END) AS lines_missing_value
    FROM first_purchase AS f
    LEFT JOIN amazon_purchase.amazon_purchase AS p
        ON p.customer_id = f.customer_id
       AND p.order_date > f.first_purchase_date
       AND p.order_date <= DATE_ADD(f.first_purchase_date, INTERVAL 90 DAY)
    GROUP BY f.customer_id
),
spend_targets AS (
    SELECT
        repeat_purchase_lines,
        CASE
            WHEN repeat_purchase_lines = 0 THEN 0
            WHEN lines_missing_value = 0 THEN recorded_spend
        END AS spend_90d
    FROM shopper_spend
)
SELECT
    COUNT(*) AS eligible_shoppers,
    SUM(repeat_purchase_lines > 0) AS returned_shoppers,
    SUM(spend_90d IS NULL) AS shoppers_with_incomplete_spend,
    ROUND(AVG(spend_90d), 2) AS avg_90d_spend_per_shopper,
    ROUND(AVG(CASE WHEN repeat_purchase_lines > 0 THEN spend_90d END), 2)
        AS avg_90d_spend_per_returning_shopper
FROM spend_targets;

SELECT
    ROUND(AVG(spend_90d), 2) AS avg_spend_all_shoppers,
    ROUND(AVG(CASE WHEN repeat_purchase_lines > 0
                  THEN spend_90d END), 2) AS avg_spend_returning_shoppers
FROM spend_targets;
WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_purchase_date
    FROM amazon_purchase.amazon_purchase
    WHERE customer_id IS NOT NULL
      AND order_date BETWEEN '2018-01-01' AND '2022-12-31'
    GROUP BY customer_id
    HAVING MIN(order_date) <= '2022-10-02'
),
shopper_spend AS (
    SELECT
        f.customer_id,
        COUNT(p.order_date) AS repeat_lines,
        CASE
            WHEN COUNT(p.order_date) = 0 THEN 0
            WHEN COUNT(p.unit_price * p.quantity) = COUNT(p.order_date)
            THEN SUM(p.unit_price * p.quantity)
        END AS spend_90d
    FROM first_purchase AS f
    LEFT JOIN amazon_purchase.amazon_purchase AS p
        ON p.customer_id = f.customer_id
       AND p.order_date > f.first_purchase_date
       AND p.order_date <= DATE_ADD(f.first_purchase_date, INTERVAL 90 DAY)
    GROUP BY f.customer_id
)
SELECT
    ROUND(AVG(spend_90d), 2) AS avg_spend_all_shoppers,
    ROUND(AVG(CASE WHEN repeat_lines > 0 THEN spend_90d END), 2)
        AS avg_spend_returning_shoppers
FROM shopper_spend;

CREATE OR REPLACE VIEW amazon_purchase.shopper_model_data AS
WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_purchase_date
    FROM amazon_purchase.amazon_purchase
    WHERE customer_id IS NOT NULL
      AND order_date BETWEEN '2018-01-01' AND '2022-12-31'
    GROUP BY customer_id
    HAVING MIN(order_date) <= '2022-10-02'
),
shopper_summary AS (
    SELECT
        f.customer_id,
        f.first_purchase_date,
        SUM(CASE WHEN p.order_date = f.first_purchase_date
                 THEN p.unit_price * p.quantity END) AS first_day_spend,
        SUM(CASE WHEN p.order_date = f.first_purchase_date
                 THEN p.quantity END) AS first_day_units,
        COUNT(DISTINCT CASE WHEN p.order_date = f.first_purchase_date
                            THEN p.product_code END) AS first_day_distinct_products,
        MIN(CASE WHEN p.order_date > f.first_purchase_date
                 THEN DATEDIFF(p.order_date, f.first_purchase_date) END)
            AS days_to_return,
        SUM(CASE WHEN p.order_date > f.first_purchase_date
                 THEN p.unit_price * p.quantity ELSE 0 END) AS spend_90d
    FROM first_purchase AS f
    JOIN amazon_purchase.amazon_purchase AS p
      ON p.customer_id = f.customer_id
     AND p.order_date BETWEEN f.first_purchase_date
                          AND DATE_ADD(f.first_purchase_date, INTERVAL 90 DAY)
    GROUP BY f.customer_id, f.first_purchase_date
)
SELECT
    customer_id,
    first_purchase_date,
    first_day_spend,
    first_day_units,
    first_day_distinct_products,
    CASE WHEN days_to_return IS NULL THEN 0 ELSE 1 END AS returned_90d,
    CASE
        WHEN days_to_return IS NULL THEN 'No return'
        WHEN days_to_return <= 30 THEN '1-30 days'
        WHEN days_to_return <= 60 THEN '31-60 days'
        ELSE '61-90 days'
    END AS return_window,
    spend_90d,
    CASE
        WHEN first_purchase_date <= '2021-10-02' THEN 'train'
        WHEN first_purchase_date >= '2022-01-01' THEN 'test'
        ELSE 'gap'
    END AS data_split
FROM shopper_summary;

SELECT
    data_split,
    COUNT(*) AS shoppers,
    SUM(returned_90d) AS returned_shoppers,
    ROUND(100 * AVG(returned_90d), 2) AS repeat_rate_pct,
    ROUND(AVG(spend_90d), 2) AS avg_spend_90d
FROM amazon_purchase.shopper_model_data
GROUP BY data_split;
SELECT
    DATE_FORMAT(first_purchase_date, '%Y-%m') AS first_purchase_month,
    COUNT(*) AS shoppers,
    SUM(returned_90d) AS returned_shoppers,
    COUNT(*) - SUM(returned_90d) AS non_returning_shoppers
FROM amazon_purchase.shopper_model_data
GROUP BY DATE_FORMAT(first_purchase_date, '%Y-%m')
ORDER BY first_purchase_month;
CREATE OR REPLACE VIEW amazon_purchase.shopper_model_split AS
SELECT
    customer_id,
    first_purchase_date,
    first_day_spend,
    first_day_units,
    first_day_distinct_products,
    returned_90d,
    return_window,
    spend_90d,
    CASE
        WHEN DATE_ADD(first_purchase_date, INTERVAL 90 DAY) < '2018-07-01'
            THEN 'train'
        WHEN first_purchase_date BETWEEN '2018-07-01' AND '2018-12-31'
            THEN 'test'
    END AS data_split
FROM amazon_purchase.shopper_model_data
WHERE DATE_ADD(first_purchase_date, INTERVAL 90 DAY) < '2018-07-01'
   OR first_purchase_date BETWEEN '2018-07-01' AND '2018-12-31';
   SELECT
    data_split,
    COUNT(*) AS shoppers,
    SUM(returned_90d) AS returned,
    COUNT(*) - SUM(returned_90d) AS did_not_return
FROM amazon_purchase.shopper_model_split
GROUP BY data_split;
SELECT
    first_day_spend,
    first_day_units,
    first_day_distinct_products,
    returned_90d,
    data_split
FROM amazon_purchase.shopper_model_split;

WITH timing_summary AS (
    SELECT
        return_window,
        COUNT(*) AS shoppers,
        AVG(spend_90d) AS avg_spend
    FROM amazon_purchase.shopper_model_split
    WHERE data_split = 'test'
    GROUP BY return_window
)
SELECT
    return_window,
    shoppers,
    ROUND(100.0 * shoppers / SUM(shoppers) OVER (), 2) AS pct_of_test_shoppers,
    ROUND(avg_spend, 2) AS avg_spend_90d
FROM timing_summary
ORDER BY CASE return_window
    WHEN '1-30 days' THEN 1
    WHEN '31-60 days' THEN 2
    WHEN '61-90 days' THEN 3
    WHEN 'No return' THEN 4
END;

SELECT
    first_day_spend,
    first_day_units,
    first_day_distinct_products,
    spend_90d,
    data_split
FROM amazon_purchase.shopper_model_split;

WITH ranked AS (
    SELECT
        DATE_FORMAT(first_purchase_date, '%Y-%m') AS cohort_month,
        returned_90d,
        ROW_NUMBER() OVER (
            ORDER BY first_day_spend, customer_id
        ) AS spend_rank
    FROM amazon_purchase.shopper_model_split
    WHERE data_split = 'test'
      AND first_day_spend IS NOT NULL
)
SELECT
    cohort_month,
    COUNT(*) AS shoppers,
    SUM(returned_90d = 0) AS non_returners,
    ROUND(100 * AVG(returned_90d = 0), 2) AS cohort_non_return_pct,
    SUM(spend_rank <= 101) AS shortlisted,
    SUM(spend_rank <= 101 AND returned_90d = 0) AS shortlisted_non_returners,
    ROUND(
        100.0 * SUM(spend_rank <= 101 AND returned_90d = 0)
        / NULLIF(SUM(spend_rank <= 101), 0),
        2
    ) AS shortlist_non_return_pct
FROM ranked
GROUP BY cohort_month
ORDER BY cohort_month;
WITH test_shoppers AS (
    SELECT
        customer_id,
        first_purchase_date,
        first_day_spend,
        returned_90d,
        return_window,
        spend_90d,
        CASE WHEN first_day_spend IS NOT NULL THEN
            ROW_NUMBER() OVER (
                ORDER BY first_day_spend IS NULL, first_day_spend, customer_id
            )
        END AS spend_rank
    FROM amazon_purchase.shopper_model_split
    WHERE data_split = 'test'
)
SELECT
    DATE_FORMAT(first_purchase_date, '%Y-%m') AS cohort_month,
    first_day_spend,
    returned_90d,
    1 - returned_90d AS did_not_return,
    return_window,
    CASE return_window
        WHEN '1-30 days' THEN 1
        WHEN '31-60 days' THEN 2
        WHEN '61-90 days' THEN 3
        ELSE 4
    END AS return_window_sort,
    spend_90d,
    CASE WHEN spend_rank <= 101 THEN 1 ELSE 0 END AS shortlisted
FROM test_shoppers;