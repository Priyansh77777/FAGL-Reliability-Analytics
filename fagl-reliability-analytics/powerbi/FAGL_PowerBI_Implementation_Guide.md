# FAGL_PowerBI_Implementation_Guide.md
### Corporate-Grade Dashboard Suite for the FAGL vs PCP Reliability Decision

**Data model:** Single fact table `weekly_reliability` (or the `v_weekly_scorecard` view from the SQL Playbook) joined to `well_master` and `lift_method_reference`. Load `fagl_weekly_reliability_data.csv` as the fact table; all measures below assume the column names from that CSV.

**Global note for every dashboard:** any visual touching `Fines_Proxy_Index`, `Estimated_Maintenance_Cost_INR`, or `Estimated_Production_Loss_INR` must carry a footer text box: *"Synthetic data — demonstration only. Not RIL production or financial records."* This is a design requirement, not a suggestion.

---

## Dashboard 1 — Executive Overview

**Business objective:** Answer "is this well getting more or less reliable, and what is it costing us?" in one screen, for someone who will look at it for 15 seconds.

**Stakeholder audience:** Asset manager, senior operations leadership.

**KPI cards:** Total Trips (104wk), Total Workovers (104wk), Avg Availability %, Total Cost of Unreliability (Maintenance + Production Loss).

**Visuals:**
- Large traffic-light indicator (Red/Yellow/Green) driven by the Reliability Index threshold.
- Headline auto-text callout: "Failures have risen ~70% year-over-year; workovers drive 93% of maintenance cost from 21% of events."
- Sparkline of weekly Reliability Index, 104 weeks.

**DAX Measures:**
```dax
Total Trips = SUM(weekly_reliability[Pump_Trips])
Total Workovers = SUM(weekly_reliability[Workovers])
Avg Availability % = AVERAGE(weekly_reliability[Availability_Percent])

Total Cost of Unreliability =
    SUM(weekly_reliability[Estimated_Maintenance_Cost_INR]) +
    SUM(weekly_reliability[Estimated_Production_Loss_INR])

Reliability Health Status =
VAR CurrentAvail = [Avg Availability %]
RETURN
    SWITCH(
        TRUE(),
        CurrentAvail >= 95, "Green",
        CurrentAvail >= 85, "Yellow",
        "Red"
    )

YoY Trip Growth % =
VAR Year1 = CALCULATE([Total Trips], weekly_reliability[Week_ID] <= 52)
VAR Year2 = CALCULATE([Total Trips], weekly_reliability[Week_ID] > 52)
RETURN DIVIDE(Year2 - Year1, Year1)
```

**Slicers:** Week range (slider), Well (single-well today, extensible).

**Drill-through:** Click the traffic light → Dashboard 3 (Reliability Analytics) filtered to the same week range.

**Executive insight:** "Reliability is deteriorating (Year 2 trips up 70% vs Year 1) and cost is concentrated: 21% of events drive 93% of maintenance cost — this is a small, well-defined problem, not a broad one."

---

## Dashboard 2 — Production Analytics

**Business objective:** Confirm production has stayed within its historical envelope even as reliability degraded — supporting "this is a reliability problem, not a production problem."

**Stakeholder audience:** Production engineers, reservoir engineering.

**KPI cards:** Avg Gas Production, Avg Water Production, Weeks Within Historical Band %.

**Visuals:**
- Waterfall/bridge chart: Expected Gas (reservoir baseline) → minus Downtime-Attributable Loss → Actual Gas. This separates reservoir-driven vs. downtime-driven production, correcting the earlier version's overstated coupling.
- Band chart showing Gas Production against the 1,300–2,600 SCMD historical range.
- Scatter: Downtime Hours vs. Gas Production (weak/moderate relationship, not a strong deterministic one).

**DAX Measures:**
```dax
Avg Gas Production = AVERAGE(weekly_reliability[Gas_Production_SCMD])
Avg Water Production = AVERAGE(weekly_reliability[Water_Production_m3_day])

Weeks Within Historical Band % =
VAR InBand =
    CALCULATE(
        COUNTROWS(weekly_reliability),
        weekly_reliability[Gas_Production_SCMD] >= 1300,
        weekly_reliability[Gas_Production_SCMD] <= 2600
    )
RETURN DIVIDE(InBand, COUNTROWS(weekly_reliability))

Downtime-Attributable Production Loss (SCM) =
SUMX(
    weekly_reliability,
    weekly_reliability[Downtime_Hours] / 24 * weekly_reliability[Gas_Production_SCMD]
)
```

**Slicers:** Week range, downtime threshold (>0 hrs / >40 hrs).

**Drill-through:** Click any week on the band chart → weekly detail table with trips/workovers/downtime for that week.

**Executive insight:** "Gas production remained inside its historical band in 100% of weeks (or state the actual computed %) — the well never lost lifting capacity; it lost uptime."

---

## Dashboard 3 — Reliability Analytics

**Business objective:** Visualize the acceleration in failures — the central evidence for the FAGL business case — and surface anomalies automatically.

**Stakeholder audience:** Reliability engineers, maintenance planning.

**KPI cards:** MTBF (trailing 8-week), MTTR (trailing 8-week), Failure Rate (weekly), % Weeks Anomalous.

**Visuals:**
- Stacked bar: Pump Trips + Workovers per week (hero visual, `wk_chart1` style).
- Line: 8-week rolling average trips, with anomaly weeks marked (Z-score > 2).
- MTBF/MTTR trend lines.
- Conditional-formatted table: week-by-week classification (Clean / Minor Trip / Major Intervention).

**DAX Measures:**
```dax
MTBF (trailing 8wk) = AVERAGE(weekly_reliability[MTBF_Hours])
MTTR (trailing 8wk) = AVERAGE(weekly_reliability[MTTR_Hours])

Rolling 8wk Avg Trips =
AVERAGEX(
    DATESINPERIOD(weekly_reliability[Week_Date], MAX(weekly_reliability[Week_Date]), -8, WEEK),
    weekly_reliability[Pump_Trips]
)

Trip Z-Score =
VAR MeanTrips = AVERAGE(weekly_reliability[Pump_Trips])
VAR StdTrips = STDEV.P(weekly_reliability[Pump_Trips])
RETURN DIVIDE(weekly_reliability[Pump_Trips] - MeanTrips, StdTrips)

Is Anomalous Week = IF([Trip Z-Score] > 2, "Yes", "No")

% Weeks Anomalous =
DIVIDE(
    CALCULATE(COUNTROWS(weekly_reliability), [Trip Z-Score] > 2),
    COUNTROWS(weekly_reliability)
)
```

**Slicers:** Week range, week classification (Clean/Minor/Major), anomalous-only toggle.

**Drill-through:** Click an anomalous week → filtered view of that week's Fines Proxy Index and surrounding 4 weeks (to visually confirm whether it's a real spike or noise).

**Executive insight:** "5 of 104 weeks are statistically anomalous failure clusters — these, not the average trend, are where root-cause investigation should focus first."

---

## Dashboard 4 — Maintenance Analytics

**Business objective:** Show that a small number of workover events drive most of the cost — the Pareto story — and make the cost *build-up*, not just the total, visible.

**Stakeholder audience:** Maintenance managers, finance business partners.

**KPI cards:** Total Maintenance Cost, Total Production Loss Cost, Workover Cost Share %.

**Visuals:**
- **Pareto chart** (hero visual): event share vs. cost share for Trips vs. Workovers (`wk_chart5_pareto.png` style) — 20.6% of events, 93.1% of maintenance cost (the maintenance-only split; a separate, broader total-cost split including production loss is 66.5%/28.6%/4.9% — see Final Project Report §4).
- Cumulative cost line (Maintenance + Production Loss) over 104 weeks.
- Cost build-up stacked bar per event type: Rig Day-Rate component vs. Parts/Crew component (reinforces "methodology, not a fabricated number").

**DAX Measures:**
```dax
Total Maintenance Cost = SUM(weekly_reliability[Estimated_Maintenance_Cost_INR])
Total Production Loss Cost = SUM(weekly_reliability[Estimated_Production_Loss_INR])

Workover Event Share % =
DIVIDE(SUM(weekly_reliability[Workovers]),
       SUM(weekly_reliability[Workovers]) + SUM(weekly_reliability[Pump_Trips]))

Cumulative Cost of Unreliability =
CALCULATE(
    [Total Maintenance Cost] + [Total Production Loss Cost],
    FILTER(ALL(weekly_reliability), weekly_reliability[Week_ID] <= MAX(weekly_reliability[Week_ID]))
)
```
*(Workover Cost Share %, i.e. the 93.1% maintenance-only figure, is computed at the row-event level in the underlying generation model and should be loaded as a precomputed field or reproduced via the Pareto SQL query in the SQL Playbook — DAX alone cannot separate trip-cost from workover-cost components if only the combined `Estimated_Maintenance_Cost_INR` column is loaded; load `cost_breakdown_internal.csv` as a second table if this split needs to be interactive in Power BI rather than a static chart.)*

**Slicers:** Week range, cost threshold.

**Drill-through:** Click the Pareto bar for Workovers → list of every workover week with its individual cost.

**Executive insight:** "You don't need to fix every failure mode — fixing the 21% of events that are workovers addresses 93% of the pure repair-cost problem, and remains the single largest driver even once deferred-production cost is added in."

---

## Dashboard 5 — Decision Framework

**Business objective:** Convert the whole analysis into the one slide an executive needs to make the call, including showing how hard the recommendation was stress-tested.

**Stakeholder audience:** Senior management, capital allocation committee.

**KPI cards:** PCP Weighted Score (3.75), FAGL Weighted Score (7.90), Monte Carlo Robustness (100%).

**Visuals:**
- Radar/spider chart: PCP vs. FAGL across the 6 weighted criteria.
- **Tornado chart:** score-gap sensitivity per criterion (how much the FAGL-PCP gap moves as each weight varies ±30%).
- Risk Matrix (2×2: Likelihood × Impact) — see Final Project Report §6.3.
- Illustrative breakeven bar (~14 weeks) with the "Illustrative Example Only" label locked to the visual.

**DAX Measures (weights and scores loaded as a small static table, `DecisionMatrix`):**
```dax
PCP Weighted Score = SUMX(DecisionMatrix, DecisionMatrix[Weight] * DecisionMatrix[PCP_Score])
FAGL Weighted Score = SUMX(DecisionMatrix, DecisionMatrix[Weight] * DecisionMatrix[FAGL_Score])
Score Gap = [FAGL Weighted Score] - [PCP Weighted Score]

-- Monte Carlo results are pre-computed (Python) and loaded as a static table
-- MonteCarloResults(Trial, PerturbedGap); DAX just aggregates:
Monte Carlo Win Rate % =
DIVIDE(
    CALCULATE(COUNTROWS(MonteCarloResults), MonteCarloResults[PerturbedGap] > 0),
    COUNTROWS(MonteCarloResults)
)
```

**Slicers:** Weight-scenario toggle (Base Case / Reliability-Priority / Cost-Priority / Risk-Priority preset weight sets).

**Drill-through:** Click a criterion on the tornado chart → the underlying rubric text explaining why PCP/FAGL received that score.

**Executive insight:** "The recommendation to switch is robust to 2,000 simulated weight scenarios — it only flips if you weight Operational Risk alone, to the exclusion of everything else."

---

## Dashboard 6 — Root Cause Analytics

**Business objective:** Make the Fishbone/5-Whys/Pareto structure interactive and keep facts, assumptions, and hypotheses visually distinct so no one mistakes one for another.

**Stakeholder audience:** Reliability engineers, engineering management, auditors of the analysis itself.

**KPI cards:** % of RCA statements classified Fact / Assumption / Hypothesis.

**Visuals:**
- Fishbone diagram as a static image (Power BI doesn't natively render Ishikawa diagrams — import as an image or build with an R/Python visual).
- Color-coded RCA statement table: Green = Fact, Yellow = Assumption, Blue = Hypothesis (matches the classification in the Final Project Report §5).
- Pareto chart (same as Dashboard 4, cross-referenced).

**DAX Measures:**
```dax
-- RCA statements loaded as a static table `RCA_Statements(Statement, Classification)`
Fact Count = CALCULATE(COUNTROWS(RCA_Statements), RCA_Statements[Classification] = "Fact")
Assumption Count = CALCULATE(COUNTROWS(RCA_Statements), RCA_Statements[Classification] = "Assumption")
Hypothesis Count = CALCULATE(COUNTROWS(RCA_Statements), RCA_Statements[Classification] = "Hypothesis")
```

**Slicers:** Classification filter (view only Facts, only Assumptions, or only Hypotheses).

**Drill-through:** None needed — this dashboard is itself a drill-through target from Dashboard 1.

**Executive insight:** "The root-cause conclusion rests on 4 directly-stated facts and 2 reasonable assumptions — no invented field evidence was used."

---

## Dashboard 7 — Financial Justification

**Business objective:** Present the cost-estimation methodology transparently — formulas, not fabricated totals — so a finance stakeholder can swap in real inputs the moment they're available.

**Stakeholder audience:** Finance business partners, capital planning.

**KPI cards:** Illustrative Breakeven (weeks), Illustrative Annualized Run-Rate, Cost Avoidance % Assumption.

**Visuals:**
- Formula-builder visual (a table showing each cost formula with its labeled inputs: Real / Assumed / Placeholder).
- Sensitivity table: breakeven weeks across a grid of capex × cost-avoidance-% assumptions.
- "Cumulative Cost of Inaction vs. Illustrative Capex" line chart with a threshold-crossing marker (see SQL Playbook §7.3).

**DAX Measures:**
```dax
-- Illustrative constants — loaded as parameters so a finance user can override them
Illustrative FAGL Capex = 4500000
Illustrative Weekly Opex = 15000
Cost Avoidance Assumption % = 0.85

Illustrative Weekly Saving =
    ((AVERAGE(weekly_reliability[Estimated_Maintenance_Cost_INR]) +
      AVERAGE(weekly_reliability[Estimated_Production_Loss_INR])) * [Cost Avoidance Assumption %])
    - [Illustrative Weekly Opex]

Illustrative Breakeven Weeks = DIVIDE([Illustrative FAGL Capex], [Illustrative Weekly Saving])

Cumulative Cost of Inaction =
CALCULATE(
    SUM(weekly_reliability[Estimated_Maintenance_Cost_INR]) + SUM(weekly_reliability[Estimated_Production_Loss_INR]),
    FILTER(ALL(weekly_reliability), weekly_reliability[Week_ID] <= MAX(weekly_reliability[Week_ID]))
)

Breakeven Crossed Flag = IF([Cumulative Cost of Inaction] >= [Illustrative FAGL Capex], "Yes", "No")
```

**Slicers:** Capex assumption (parameter slider), cost-avoidance % assumption (parameter slider) — this is the one dashboard where slicers double as "what-if" controls for a live finance conversation.

**Drill-through:** None — this is the terminal dashboard in the navigation flow (Executive → Decision → Financial).

**Executive insight:** "Under illustrative assumptions (INR 40/SCM gas price, 85% cost avoidance), cumulative avoided cost would exceed a full FAGL capex outlay in roughly 14 weeks — the number is illustrative, the methodology and its sensitivity to assumptions are real."

---

## Navigation flow (how a user should move through the suite)

```
Dashboard 1 (Executive Overview)
   ├─→ Dashboard 3 (Reliability Analytics) — "why is the health score red/yellow?"
   ├─→ Dashboard 5 (Decision Framework) — "what should we do about it?"
   │        ├─→ Dashboard 6 (Root Cause Analytics) — "what's the evidence?"
   │        └─→ Dashboard 7 (Financial Justification) — "what does it cost/save?"
   ├─→ Dashboard 2 (Production Analytics) — "did we actually lose gas?"
   └─→ Dashboard 4 (Maintenance Analytics) — "where does the money go?"
```

This mirrors how a real stakeholder conversation actually unfolds — start at the headline, branch into whichever question the audience asks next.
