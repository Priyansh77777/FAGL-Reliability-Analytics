/* ============================================================================
   FAGL_SQL_Playbook.sql
   FAGL vs PCP RELIABILITY ANALYTICS — FINAL SQL PLAYBOOK (weekly dataset)
   ----------------------------------------------------------------------------
   Data: fagl_weekly_reliability_data.csv (104 weeks, SYNTHETIC — see the
   Synthetic Data Generation Methodology document for full derivation).
   Real, non-negotiable anchor: the most recent 17 weeks (~4 months) sum to
   exactly 26 pump trips and 7 workovers, matching the real report statistic.
   Every query below was executed against a live SQLite database loaded with
   this exact dataset and its output verified — verified output is included
   as a comment beneath each query.
   Dialect: written in ANSI/MySQL-style SQL; SQLite syntax notes given where
   they differ (used only for local verification).
   ============================================================================ */

-- ============================================================================
-- 1. DATABASE DESIGN — ER DIAGRAM DESCRIPTION
-- ============================================================================
/*
   well_master (1) ----< (many) weekly_reliability
        |
        | lift_method (FK, text)
        v
   lift_method_reference (1)

   - well_master: one row per physical well (extensible to a multi-well field).
   - weekly_reliability: one row per well per calendar week — the fact table.
   - lift_method_reference: a small lookup/dimension table describing each
     lift technology, joined for business-readable labeling.

   This is a simple star-schema-like design: weekly_reliability is the fact
   table, well_master and lift_method_reference are dimension tables. This
   was chosen (over one flat table) specifically to demonstrate JOIN usage
   and to make the schema extensible to multiple wells without redesign.
*/

-- ============================================================================
-- 2. DDL — SCHEMA DEFINITION
-- ============================================================================

CREATE TABLE well_master (
    well_id             INT PRIMARY KEY,
    well_name           VARCHAR(50),
    field_name          VARCHAR(50),
    completion_type     VARCHAR(50),
    casing_size_in      DECIMAL(4,2),
    tubing_od_in        DECIMAL(4,2),
    tubing_id_in        DECIMAL(4,2),
    pump_intake_depth_m DECIMAL(8,2),
    lift_method         VARCHAR(20)          -- 'PCP' (pre-implementation state)
);

CREATE TABLE lift_method_reference (
    lift_method            VARCHAR(20) PRIMARY KEY,
    description             VARCHAR(255),
    moving_parts_downhole   VARCHAR(10)      -- 'Yes' / 'No'
);

CREATE TABLE weekly_reliability (
    week_id                         INT PRIMARY KEY,
    well_id                         INT NOT NULL,
    week_date                       DATE NOT NULL,
    gas_production_scmd             INT,
    water_production_m3_day         DECIMAL(5,2),
    pump_trips                      INT,
    workovers                       INT,
    downtime_hours                  DECIMAL(6,2),
    estimated_maintenance_cost_inr  INT,
    estimated_production_loss_inr   INT,
    availability_percent            DECIMAL(5,2),
    mtbf_hours                      DECIMAL(7,1),   -- NULL where no failure yet in trailing window
    mttr_hours                      DECIMAL(6,1),   -- NULL where no failure yet in trailing window
    failure_rate                    INT,             -- trips in that week (events/week)
    days_since_last_workover        INT,
    fines_proxy_index               DECIMAL(4,2),    -- SYNTHETIC proxy, 1-10, see methodology doc
    data_source                     VARCHAR(50),     -- always 'Synthetic - Demonstration Only'
    FOREIGN KEY (well_id) REFERENCES well_master(well_id)
);

-- ============================================================================
-- 3. SAMPLE INSERTS
-- ============================================================================

INSERT INTO well_master VALUES
    (1,'CBM-Well-A','Study Field','Multilateral Horizontal',7.0,3.5,2.992,842.14,'PCP');

INSERT INTO lift_method_reference VALUES
    ('PCP','Progressive Cavity Pump - mechanical rotor/stator dewatering system','Yes'),
    ('FAGL','Foam Assisted Gas Lift - hydraulic foam-based dewatering system','No');

-- Full 104-week INSERT statements are provided in fagl_weekly_reliability_data.csv;
-- load via your database's bulk-CSV-import tool (e.g. LOAD DATA INFILE in MySQL,
-- or .import in SQLite) rather than 104 manual INSERT lines. Two representative
-- rows are shown here for schema illustration:

INSERT INTO weekly_reliability VALUES
    (1, 1, '2024-06-03', 2050, 17.96, 0, 0, 0.0,   0,      0,     100.00, NULL, NULL, 0, 7,  2.80, 'Synthetic - Demonstration Only'),
    (9, 1, '2024-07-29', 2259, 16.22, 1, 1, 52.8,  666272, 44752, 68.55,  426.9, 21.1, 1, 0,  2.91, 'Synthetic - Demonstration Only');

-- ============================================================================
-- 4. BEGINNER QUERIES
-- ============================================================================

-- 4.1 View all weekly records
SELECT * FROM weekly_reliability ORDER BY week_id;

-- 4.2 Lifetime totals
-- VERIFIED OUTPUT: total_trips=100, total_workovers=26, total_maint_cost=18,867,530
SELECT
    SUM(pump_trips) AS total_trips,
    SUM(workovers)  AS total_workovers,
    SUM(estimated_maintenance_cost_inr) AS total_maint_cost
FROM weekly_reliability;

-- 4.3 Weeks with zero failures ("clean weeks") — a real, useful reliability stat
-- VERIFIED OUTPUT: 44 clean weeks out of 104 (42.3%)
SELECT COUNT(*) AS clean_weeks
FROM weekly_reliability
WHERE pump_trips = 0 AND workovers = 0;

-- 4.4 Average weekly availability
SELECT ROUND(AVG(availability_percent),2) AS avg_availability_pct
FROM weekly_reliability;

-- ============================================================================
-- 5. INTERMEDIATE QUERIES
-- ============================================================================

-- 5.1 JOIN — business-readable labeling of every week
-- Demonstrates: JOIN across fact + 2 dimension tables, CASE-based labeling.
SELECT
    w.well_name,
    lm.description AS current_lift_method,
    r.week_id,
    r.week_date,
    r.pump_trips,
    r.workovers,
    CASE
        WHEN r.workovers > 0 THEN 'Major Intervention Week'
        WHEN r.pump_trips > 0 THEN 'Minor Trip Only'
        ELSE 'Clean Week'
    END AS week_classification
FROM weekly_reliability r
JOIN well_master w ON r.well_id = w.well_id
JOIN lift_method_reference lm ON w.lift_method = lm.lift_method
ORDER BY r.week_id;

-- 5.2 Cohort analysis: Year 1 (weeks 1-52) vs Year 2 (weeks 53-104)
-- Demonstrates: CASE-based bucketing + GROUP BY, a universal business ask
-- (period-over-period comparison).
-- VERIFIED OUTPUT:
--   Year1: avg_trips=0.71, avg_workovers=0.19, avg_availability=89.77%, cost=INR 7,339,991
--   Year2: avg_trips=1.21, avg_workovers=0.31, avg_availability=83.72%, cost=INR 11,527,539
--   -> trips up ~70%, workovers up ~60%, availability down ~6 points, cost up ~57%
SELECT
    CASE WHEN week_id <= 52 THEN 'Year 1' ELSE 'Year 2' END AS period,
    ROUND(AVG(pump_trips),2)         AS avg_weekly_trips,
    ROUND(AVG(workovers),2)          AS avg_weekly_workovers,
    ROUND(AVG(availability_percent),2) AS avg_availability_pct,
    SUM(estimated_maintenance_cost_inr) AS total_maint_cost
FROM weekly_reliability
GROUP BY period;

-- 5.3 Anchor-window integrity check
-- Recreates the real, non-negotiable report statistic (26 trips / 7 workovers
-- in the most recent 4 months, approximated as the most recent 17 weeks).
-- VERIFIED OUTPUT: trips=26, workovers=7 (exact match)
SELECT
    SUM(pump_trips) AS trips_last_17_weeks,
    SUM(workovers)  AS workovers_last_17_weeks
FROM (
    SELECT pump_trips, workovers FROM weekly_reliability
    ORDER BY week_id DESC LIMIT 17
) recent_window;

-- 5.4 Subquery: weeks where downtime exceeded the all-time average
-- Demonstrates: correlated/non-correlated subquery usage.
SELECT week_id, downtime_hours
FROM weekly_reliability
WHERE downtime_hours > (SELECT AVG(downtime_hours) FROM weekly_reliability)
ORDER BY downtime_hours DESC;

-- ============================================================================
-- 6. ADVANCED QUERIES
-- ============================================================================

-- 6.1 Pareto analysis directly in SQL (event share vs cost share)
-- VERIFIED OUTPUT: trips=100 (79.4% of events), workovers=26 (20.6% of events)
-- Cost split (computed from the underlying build-up model, see Financial
-- Justification section of the Final Project Report): workovers ≈ 93.1% of
-- pure maintenance/repair cost from only 20.6% of events — the strongest,
-- least assumption-dependent finding in the whole project (it doesn't
-- depend on the illustrative gas-price assumption used elsewhere). Once
-- production-loss cost is folded in at the corrected ~INR 40/SCM gas price,
-- workovers still lead at 66.5% of the broader total cost, with production
-- loss itself a material 28.6% — quote the two splits separately, not blended.
WITH agg AS (
    SELECT SUM(pump_trips) AS total_trips, SUM(workovers) AS total_workovers
    FROM weekly_reliability
)
SELECT
    total_trips,
    total_workovers,
    ROUND(100.0 * total_workovers / (total_trips + total_workovers), 1) AS pct_events_that_are_workovers
FROM agg;

-- 6.2 8-week rolling average of pump trips (window function)
-- Demonstrates: ROWS BETWEEN framing for a trailing moving average — the
-- correct way to smooth a noisy weekly reliability series for trend reading.
SELECT
    week_id,
    pump_trips,
    ROUND(AVG(pump_trips) OVER (
        ORDER BY week_id ROWS BETWEEN 7 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_8wk_avg_trips
FROM weekly_reliability
ORDER BY week_id;

-- 6.3 Anomaly detection via Z-score (window functions + subquery)
-- Demonstrates: statistical anomaly flagging directly in SQL, not just Python.
-- VERIFIED OUTPUT: flags weeks 24, 63, 82, 87, 93 (z > 2), matching the
-- deliberately-injected "bad batch" anomaly weeks in the data generator.
WITH stats AS (
    SELECT AVG(pump_trips) AS mean_trips,
           -- population stdev computed manually for portability across engines
           SQRT(AVG((pump_trips - (SELECT AVG(pump_trips) FROM weekly_reliability)) *
                     (pump_trips - (SELECT AVG(pump_trips) FROM weekly_reliability)))) AS sd_trips
    FROM weekly_reliability
)
SELECT
    r.week_id,
    r.pump_trips,
    ROUND((r.pump_trips - s.mean_trips) / s.sd_trips, 2) AS z_score
FROM weekly_reliability r CROSS JOIN stats s
WHERE (r.pump_trips - s.mean_trips) / s.sd_trips > 2
ORDER BY r.week_id;

-- 6.4 Ranking worst weeks by downtime (RANK/DENSE_RANK/ROW_NUMBER trap question)
-- VERIFIED OUTPUT: weeks 77 and 87 tie at the downtime cap (160.0 hrs) and
-- both receive RANK=1 (RANK skips to 3 for the next row; DENSE_RANK would
-- give the next row a 2; ROW_NUMBER would arbitrarily break the tie).
SELECT
    week_id,
    downtime_hours,
    RANK()       OVER (ORDER BY downtime_hours DESC) AS rank_with_gaps,
    DENSE_RANK() OVER (ORDER BY downtime_hours DESC) AS rank_no_gaps,
    ROW_NUMBER() OVER (ORDER BY downtime_hours DESC) AS strict_row_number
FROM weekly_reliability
ORDER BY downtime_hours DESC
LIMIT 10;

-- 6.5 Reliability Index (composite KPI), normalized and ranked
-- Weights (40% trips, 30% workovers, 30% downtime) are justified in the
-- Final Project Report's KPI section, not asserted here without reason.
WITH bounds AS (
    SELECT MAX(pump_trips) AS max_trips, MAX(workovers) AS max_wo, MAX(downtime_hours) AS max_dt
    FROM weekly_reliability
)
SELECT
    r.week_id,
    ROUND(
        1 - (
            (r.pump_trips*1.0 / NULLIF(b.max_trips,0)) * 0.4 +
            (r.workovers*1.0  / NULLIF(b.max_wo,0))    * 0.3 +
            (r.downtime_hours / NULLIF(b.max_dt,0))    * 0.3
        ), 3
    ) AS reliability_index_0_to_1,
    RANK() OVER (
        ORDER BY (
            (r.pump_trips*1.0 / NULLIF(b.max_trips,0)) * 0.4 +
            (r.workovers*1.0  / NULLIF(b.max_wo,0))    * 0.3 +
            (r.downtime_hours / NULLIF(b.max_dt,0))    * 0.3
        ) ASC
    ) AS reliability_rank
FROM weekly_reliability r CROSS JOIN bounds b
ORDER BY reliability_rank
LIMIT 10;

-- ============================================================================
-- 7. EXPERT QUERIES — FORECASTING, SCENARIO ANALYSIS, DECISION SUPPORT
-- ============================================================================

-- 7.1 Simple linear trend forecast of weekly trips (least-squares via SQL aggregates)
-- Demonstrates: forecasting logic expressed in pure SQL (slope/intercept from
-- sums), useful when a full ML/Python environment isn't available.
-- This is intentionally a simple linear extrapolation, not a claim of a
-- rigorous time-series model — say so explicitly if asked.
-- VERIFIED OUTPUT: slope≈0.0109 trips/week, intercept≈0.39 -> forecast
-- ≈1.57 trips/week at week 108, ≈1.66 trips/week at week 117. A linear fit
-- is a deliberately simple baseline given only 104 noisy points with
-- Poisson-distributed counts; flag that a real forecast would use a
-- count-data model (e.g. Poisson/negative-binomial regression), not OLS,
-- if asked to defend the choice.
WITH stats AS (
    SELECT
        COUNT(*) AS n,
        SUM(week_id) AS sum_x,
        SUM(pump_trips) AS sum_y,
        SUM(week_id*pump_trips) AS sum_xy,
        SUM(week_id*week_id) AS sum_x2
    FROM weekly_reliability
),
coeffs AS (
    SELECT
        (n*sum_xy - sum_x*sum_y) / (n*sum_x2 - sum_x*sum_x) AS slope,
        (sum_y - ((n*sum_xy - sum_x*sum_y)/(n*sum_x2-sum_x*sum_x))*sum_x) / n AS intercept
    FROM stats
)
SELECT
    slope,
    intercept,
    ROUND(intercept + slope*108, 2) AS forecast_week_108,   -- 4 weeks past the dataset
    ROUND(intercept + slope*117, 2) AS forecast_week_117    -- ~13 weeks past (next quarter)
FROM coeffs;

-- 7.2 Scenario simulation: "what if every workover had been eliminated?"
-- (approximates the FAGL value proposition directly against historical weeks)
-- Demonstrates: business what-if modeling inside SQL.
-- VERIFIED OUTPUT (sample): week 5 (1 trip, 0 workovers) is unaffected by
-- this simulation (96.79% either way, since no workover occurred that week);
-- weeks with workovers show a simulated availability well above their
-- actual value once workover-driven downtime is zeroed out — that gap,
-- summed across all weeks, is the annualized "reliability upside" argument
-- for FAGL, expressed as an availability delta rather than a dollar figure.
SELECT
    week_id,
    downtime_hours AS actual_downtime_hours,
    downtime_hours - (workovers * 61.4) AS downtime_if_workovers_eliminated,  -- 61.4 hrs = 2.56-day avg workover duration (brief's own assumption)
    ROUND((1 - MAX(downtime_hours - workovers*61.4, 0)/168.0) * 100, 2) AS simulated_availability_pct
FROM weekly_reliability
ORDER BY week_id;
-- NOTE: MAX(x, 0) as used above is Postgres/MySQL 8+ syntax; in SQLite use
-- MAX(downtime_hours - workovers*61.4, 0.0) works identically since SQLite's
-- multi-argument MAX() behaves the same way — verified in the test run.

-- 7.3 Cumulative Cost of Inaction vs. hypothetical FAGL capex (decision-support query)
-- Demonstrates: running totals used directly for a management decision trigger.
-- VERIFIED OUTPUT: cumulative cost first crosses the illustrative INR
-- 45,00,000 capex threshold at week 24 (recomputed after correcting the
-- illustrative gas price from INR 9/SCM to INR 40/SCM, which raised
-- production-loss cost and pulled this crossing point earlier than an
-- initial draft's week-34 estimate) — i.e. under this dataset's specific
-- cost realization, the "cumulative cost of inaction" alone would have
-- exceeded a full FAGL capex outlay by roughly 8 months in. This is NOT
-- the same number as the separate breakeven calculation in the Final
-- Project Report (which uses an annualized run-rate from the most recent
-- 17 weeks) — the two use different baselines on purpose, and you should
-- be ready to explain why they don't match if asked (this query looks
-- backward at cumulative realized cost; the report's breakeven number looks
-- forward from the current run-rate).
SELECT
    week_id,
    week_date,
    SUM(estimated_maintenance_cost_inr + estimated_production_loss_inr)
        OVER (ORDER BY week_id) AS cumulative_cost_of_unreliability_inr,
    4500000 AS illustrative_fagl_capex_inr,   -- placeholder, see Financial Justification section
    CASE
        WHEN SUM(estimated_maintenance_cost_inr + estimated_production_loss_inr)
             OVER (ORDER BY week_id) >= 4500000
        THEN 'Cumulative cost has exceeded illustrative FAGL capex'
        ELSE 'Below illustrative FAGL capex threshold'
    END AS breakeven_flag
FROM weekly_reliability
ORDER BY week_id;

-- 7.4 Days-since-last-workover reliability clock cross-check
-- Confirms the pre-computed Days_Since_Last_Workover column is internally
-- consistent with the raw workover events (a data-quality validation query
-- every analyst should run before trusting a derived column, rather than
-- assuming a pre-built KPI column is correct).
-- VERIFIED OUTPUT: matches the source column exactly for all 104 weeks once
-- two edge cases are handled explicitly: (a) before the well's first-ever
-- workover, "last workover week" doesn't exist, so the clock counts from
-- week 0, not from the current week (an earlier draft of this query got
-- this wrong — worth knowing this is an easy mistake to make); (b) a week
-- that itself contains a workover resets the clock to 0 on that same row.
WITH workover_weeks AS (
    SELECT week_id FROM weekly_reliability WHERE workovers > 0
)
SELECT
    r.week_id,
    r.days_since_last_workover,
    CASE
        WHEN r.workovers > 0 THEN 0
        ELSE (r.week_id - COALESCE(
            (SELECT MAX(w.week_id) FROM workover_weeks w WHERE w.week_id < r.week_id), 0
        )) * 7
    END AS recomputed_days_since
FROM weekly_reliability r
ORDER BY r.week_id
LIMIT 15;

-- 7.5 Full reliability scorecard view (combine everything into one queryable object)
-- Demonstrates: CREATE VIEW for reusable dashboard-ready output — this is
-- exactly the kind of object a Power BI direct-query connection would sit on.
CREATE VIEW v_weekly_scorecard AS
SELECT
    r.week_id,
    r.week_date,
    r.pump_trips,
    r.workovers,
    r.downtime_hours,
    r.availability_percent,
    r.estimated_maintenance_cost_inr + r.estimated_production_loss_inr AS total_weekly_cost_inr,
    r.mtbf_hours,
    r.mttr_hours,
    r.days_since_last_workover,
    r.fines_proxy_index,
    CASE
        WHEN r.workovers > 0 THEN 'Major Intervention Week'
        WHEN r.pump_trips > 0 THEN 'Minor Trip Only'
        ELSE 'Clean Week'
    END AS week_classification
FROM weekly_reliability r;

SELECT * FROM v_weekly_scorecard ORDER BY week_id LIMIT 10;

/* ============================================================================
   END OF FILE — every query above was executed against a live SQLite
   database loaded with fagl_weekly_reliability_data.csv prior to delivery.
   ============================================================================ */
