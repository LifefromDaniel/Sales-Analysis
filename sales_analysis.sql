-- ============================================================
-- Sales Performance Analysis  |  2023-2024
-- Author : Daniel Garcia
-- Tools  : SQLite  |  DB Browser for SQLite
-- Purpose: Analyze pipeline health, rep performance, and
--          revenue trends to support Sales Operations decisions
-- ============================================================


-- ============================================================
-- SECTION 1  |  REVENUE OVERVIEW
-- High-level revenue and win-rate snapshot by year
-- ============================================================

SELECT
    close_year                                          AS year,
    COUNT(*)                                            AS total_opportunities,
    COUNT(CASE WHEN stage = 'Closed Won' THEN 1 END)   AS won_deals,
    COUNT(CASE WHEN stage = 'Closed Lost' THEN 1 END)  AS lost_deals,
    ROUND(
        COUNT(CASE WHEN stage = 'Closed Won' THEN 1 END) * 100.0 / COUNT(*), 1
    )                                                   AS win_rate_pct,
    ROUND(SUM(CASE WHEN stage = 'Closed Won' THEN revenue ELSE 0 END), 0)
                                                        AS total_revenue,
    ROUND(AVG(CASE WHEN stage = 'Closed Won' THEN revenue END), 0)
                                                        AS avg_deal_size
FROM opportunities
GROUP BY close_year
ORDER BY close_year;


-- ============================================================
-- SECTION 2  |  REP PERFORMANCE SCORECARD
-- Revenue attainment vs. quota, deal count, and win rate
-- Used in 1:1 coaching and QBR reporting
-- ============================================================

SELECT
    rep_name,
    region,
    segment,
    COUNT(*)                                                        AS total_opps,
    COUNT(CASE WHEN stage = 'Closed Won' THEN 1 END)               AS won_deals,
    ROUND(
        COUNT(CASE WHEN stage = 'Closed Won' THEN 1 END) * 100.0 / COUNT(*), 1
    )                                                               AS win_rate_pct,
    ROUND(SUM(CASE WHEN stage = 'Closed Won' THEN revenue ELSE 0 END), 0)
                                                                    AS total_revenue,
    ROUND(AVG(quota), 0)                                            AS avg_quota,
    ROUND(
        SUM(CASE WHEN stage = 'Closed Won' THEN revenue ELSE 0 END) /
        NULLIF(AVG(quota), 0) * 100, 1
    )                                                               AS quota_attainment_pct
FROM opportunities
GROUP BY rep_name, region, segment
ORDER BY total_revenue DESC;


-- ============================================================
-- SECTION 3  |  REVENUE BY PRODUCT AND CATEGORY
-- Identify top-performing products and revenue mix
-- Useful for GTM strategy and resource allocation
-- ============================================================

SELECT
    category,
    product_name,
    COUNT(CASE WHEN stage = 'Closed Won' THEN 1 END)               AS deals_won,
    ROUND(SUM(CASE WHEN stage = 'Closed Won' THEN revenue ELSE 0 END), 0)
                                                                    AS total_revenue,
    ROUND(AVG(CASE WHEN stage = 'Closed Won' THEN revenue END), 0) AS avg_deal_size,
    ROUND(AVG(CASE WHEN stage = 'Closed Won' THEN discount END) * 100, 1)
                                                                    AS avg_discount_pct
FROM opportunities
GROUP BY category, product_name
ORDER BY total_revenue DESC;


-- ============================================================
-- SECTION 4  |  MONTHLY REVENUE TREND (2023 vs 2024)
-- Month-over-month closed revenue for pipeline pacing
-- Used to spot seasonality and forecast risks
-- ============================================================

SELECT
    close_month                                                     AS month,
    ROUND(SUM(CASE WHEN close_year = 2023 AND stage = 'Closed Won' THEN revenue ELSE 0 END), 0)
                                                                    AS revenue_2023,
    ROUND(SUM(CASE WHEN close_year = 2024 AND stage = 'Closed Won' THEN revenue ELSE 0 END), 0)
                                                                    AS revenue_2024,
    ROUND(
        (SUM(CASE WHEN close_year = 2024 AND stage = 'Closed Won' THEN revenue ELSE 0 END) -
         SUM(CASE WHEN close_year = 2023 AND stage = 'Closed Won' THEN revenue ELSE 0 END)) * 100.0 /
        NULLIF(SUM(CASE WHEN close_year = 2023 AND stage = 'Closed Won' THEN revenue ELSE 0 END), 0), 1
    )                                                               AS yoy_growth_pct
FROM opportunities
GROUP BY close_month
ORDER BY close_month;


-- ============================================================
-- SECTION 5  |  PIPELINE STAGE FUNNEL
-- Active pipeline breakdown by stage
-- Used to identify bottlenecks and forecast coverage
-- ============================================================

SELECT
    stage,
    COUNT(*)                                AS opportunity_count,
    ROUND(SUM(revenue), 0)                  AS pipeline_value,
    ROUND(AVG(revenue), 0)                  AS avg_opp_value,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)
                                            AS pct_of_total_opps
FROM opportunities
WHERE stage NOT IN ('Closed Won', 'Closed Lost')
GROUP BY stage
ORDER BY
    CASE stage
        WHEN 'Prospecting'  THEN 1
        WHEN 'Qualified'    THEN 2
        WHEN 'Proposal'     THEN 3
        WHEN 'Negotiation'  THEN 4
    END;


-- ============================================================
-- SECTION 6  |  REGIONAL PERFORMANCE SUMMARY
-- Revenue and win rate by region and customer segment
-- Surfaces where to focus sales headcount and spend
-- ============================================================

SELECT
    region,
    segment,
    COUNT(CASE WHEN stage = 'Closed Won' THEN 1 END)               AS won_deals,
    ROUND(SUM(CASE WHEN stage = 'Closed Won' THEN revenue ELSE 0 END), 0)
                                                                    AS total_revenue,
    ROUND(
        COUNT(CASE WHEN stage = 'Closed Won' THEN 1 END) * 100.0 / COUNT(*), 1
    )                                                               AS win_rate_pct
FROM opportunities
GROUP BY region, segment
ORDER BY total_revenue DESC;


-- ============================================================
-- SECTION 7  |  TOP 10 DEALS BY REVENUE
-- Largest individual closed-won opportunities
-- Used in deal review and replication of winning patterns
-- ============================================================

SELECT
    opp_id,
    rep_name,
    product_name,
    segment,
    region,
    ROUND(revenue, 0)   AS revenue,
    discount * 100      AS discount_pct,
    close_date
FROM opportunities
WHERE stage = 'Closed Won'
ORDER BY revenue DESC
LIMIT 10;


-- ============================================================
-- SECTION 8  |  DISCOUNT IMPACT ANALYSIS  (Subquery)
-- Compare revenue per deal above vs. below average discount
-- Demonstrates subquery usage for threshold-based segmentation
-- ============================================================

SELECT
    discount_band,
    COUNT(*)                        AS deal_count,
    ROUND(AVG(revenue), 0)          AS avg_revenue_per_deal,
    ROUND(SUM(revenue), 0)          AS total_revenue
FROM (
    SELECT
        revenue,
        CASE
            WHEN discount >= (SELECT AVG(discount) FROM opportunities WHERE stage = 'Closed Won')
                THEN 'High Discount (>= avg)'
            ELSE 'Low Discount (< avg)'
        END AS discount_band
    FROM opportunities
    WHERE stage = 'Closed Won'
) sub
GROUP BY discount_band
ORDER BY avg_revenue_per_deal DESC;


-- ============================================================
-- SECTION 9  |  REP RANKING WITH WINDOW FUNCTION
-- Rank reps by revenue within their region using RANK()
-- Supports territory planning and peer benchmarking
-- ============================================================

SELECT
    rep_name,
    region,
    ROUND(SUM(CASE WHEN stage = 'Closed Won' THEN revenue ELSE 0 END), 0) AS total_revenue,
    RANK() OVER (
        PARTITION BY region
        ORDER BY SUM(CASE WHEN stage = 'Closed Won' THEN revenue ELSE 0 END) DESC
    ) AS rank_in_region
FROM opportunities
GROUP BY rep_name, region
ORDER BY region, rank_in_region;
