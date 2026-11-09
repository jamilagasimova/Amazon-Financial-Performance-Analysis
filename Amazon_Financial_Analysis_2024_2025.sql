-- AMAZON | FINANCIAL PERFORMANCE ANALYSIS (2024–2025)
-- Tools: PostgreSQL (pgAdmin), Tableau Public
-- Units: USD billions
-- Source reference: Amazon Investor Relations annual reports
-- https://ir.aboutamazon.com/annual-reports-proxies-and-shareholder-letters/default.aspx
-- IMPORTANT: The six values below are the project's supplied figures.
-- Verify them against the relevant original annual reports before presenting
-- this project as an analysis of official reported results.
-- Run this script in a NEW/EMPTY project database or schema.
-- It intentionally does not drop or delete existing data.

-- 01 | Create source table
CREATE TABLE amazon_revenue (
    year INT,
    business_segment VARCHAR(50),
    revenue_usd_billions NUMERIC(12,3),
    CONSTRAINT amazon_revenue_year_segment_unique UNIQUE (year, business_segment)
);

-- 02 | Insert source figures (one row per year and segment)
INSERT INTO amazon_revenue (year, business_segment, revenue_usd_billions)
VALUES
    (2024, 'North America', 387.497),
    (2024, 'International', 142.906),
    (2024, 'AWS', 107.556),
    (2025, 'North America', 426.305),
    (2025, 'International', 161.894),
    (2025, 'AWS', 128.725);

-- 03 | Inspect imported data
SELECT *
FROM amazon_revenue
ORDER BY year, business_segment;

-- 04 | Data quality: check for duplicate year/segment combinations
-- Expected result: zero rows.
SELECT
    year,
    business_segment,
    COUNT(*) AS record_count
FROM amazon_revenue
GROUP BY year, business_segment
HAVING COUNT(*) > 1;

-- 05 | Total revenue by year
SELECT
    year,
    ROUND(SUM(revenue_usd_billions), 1) AS total_revenue_billions
FROM amazon_revenue
GROUP BY year
ORDER BY year;

-- 06 | Total revenue year-over-year growth
WITH yearly_revenue AS (
    SELECT year, SUM(revenue_usd_billions) AS total_revenue
    FROM amazon_revenue
    GROUP BY year
)
SELECT
    current_year.year,
    ROUND(current_year.total_revenue, 1) AS current_revenue,
    ROUND(previous_year.total_revenue, 1) AS previous_revenue,
    ROUND(
        (current_year.total_revenue - previous_year.total_revenue)
        / NULLIF(previous_year.total_revenue, 0) * 100,
        2
    ) AS revenue_growth_pct
FROM yearly_revenue current_year
JOIN yearly_revenue previous_year
    ON current_year.year = previous_year.year + 1
ORDER BY current_year.year;

-- 07 | Revenue by business segment
SELECT
    year,
    business_segment,
    ROUND(SUM(revenue_usd_billions), 1) AS segment_revenue_billions
FROM amazon_revenue
GROUP BY year, business_segment
ORDER BY year, segment_revenue_billions DESC;

-- 08 | Segment-level year-over-year revenue growth
WITH segment_revenue AS (
    SELECT year, business_segment, SUM(revenue_usd_billions) AS revenue
    FROM amazon_revenue
    GROUP BY year, business_segment
),
revenue_comparison AS (
    SELECT
        year,
        business_segment,
        revenue AS current_revenue,
        LAG(revenue) OVER (
            PARTITION BY business_segment ORDER BY year
        ) AS previous_revenue
    FROM segment_revenue
)
SELECT
    year,
    business_segment,
    ROUND(current_revenue, 1) AS current_revenue,
    ROUND(previous_revenue, 1) AS previous_revenue,
    ROUND(
        (current_revenue - previous_revenue)
        / NULLIF(previous_revenue, 0) * 100,
        2
    ) AS revenue_growth_pct
FROM revenue_comparison
WHERE previous_revenue IS NOT NULL
ORDER BY revenue_growth_pct DESC;

-- 09 | Revenue share by business segment within each year
SELECT
    year,
    business_segment,
    ROUND(revenue_usd_billions, 1) AS segment_revenue,
    ROUND(
        revenue_usd_billions
        / NULLIF(SUM(revenue_usd_billions) OVER (PARTITION BY year), 0) * 100,
        2
    ) AS revenue_share_pct
FROM amazon_revenue
ORDER BY year, revenue_share_pct DESC;

-- 10 | Rank segments by 2025 versus 2024 growth
WITH segment_growth AS (
    SELECT
        business_segment,
        MAX(CASE WHEN year = 2024 THEN revenue_usd_billions END) AS revenue_2024,
        MAX(CASE WHEN year = 2025 THEN revenue_usd_billions END) AS revenue_2025
    FROM amazon_revenue
    GROUP BY business_segment
),
growth_calculation AS (
    SELECT
        business_segment,
        revenue_2024,
        revenue_2025,
        ROUND(
            (revenue_2025 - revenue_2024)
            / NULLIF(revenue_2024, 0) * 100,
            2
        ) AS growth_pct
    FROM segment_growth
),
ranked_segments AS (
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY growth_pct DESC) AS growth_rank
    FROM growth_calculation
)
SELECT
    business_segment,
    ROUND(revenue_2024, 1) AS revenue_2024,
    ROUND(revenue_2025, 1) AS revenue_2025,
    growth_pct,
    growth_rank
FROM ranked_segments
ORDER BY growth_rank;
