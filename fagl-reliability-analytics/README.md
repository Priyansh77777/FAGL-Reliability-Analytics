# FAGL vs PCP Reliability Analytics: Data-Driven Decision Making for a CBM Well

**Status: PRE-IMPLEMENTATION.** This is a decision-support analytics project. Foam Assisted Gas Lift (FAGL) has not been installed, commissioned, or field-tested on the well this project is based on.

## Overview

A petroleum engineering feasibility study — *"Pre-Implementation Assessment of Foam Assisted Gas Lift (FAGL) in CBM Wells"* — reframed as a data analytics case study.

A Coal Bed Methane (CBM) well is failing repeatedly (26 pump trips, 7 workovers in a 4-month window) because abrasive coal fines wear out its Progressive Cavity Pump (PCP). The core business question: **Should the operator continue absorbing recurring PCP repair costs, or make a capital shift to a lift technology (FAGL) that structurally removes the failure mechanism entirely?**

This repository provides the analytics layer built to answer that question: a synthetic-but-anchored weekly dataset, a verified SQL analytics playbook, a Power BI dashboard, and a decision model stress-tested with Monte Carlo simulation.

## Key Findings

* **Cost Driver (Pareto Analysis):** 20.6% of failure events (workovers) drive 93.1% of pure maintenance repair costs. When factoring in deferred production loss, workovers still dominate at 66.5% of the total cost of unreliability.
* **Deterioration Trend:** Year-over-year cohort comparison shows a 70% increase in weekly pump trips and a 60% increase in workovers, leading to a 57% increase in total maintenance costs.
* **Decision Model:** In a 2,000-trial Monte Carlo simulation of the weighted decision matrix (Reliability, Fines Handling, Maintenance, Downtime, Operational Risk, Scalability), FAGL outperformed the baseline PCP approach in 100% of trials. The only scenario where PCP wins is if decision-makers weigh "new technology commissioning risk" at 100%, completely excluding reliability and cost factors.

## Repository Structure

```text
├── reports/
│   └── FAGL_Final_Project_Report.md     # Full business framing, KPIs, EDA, root cause analysis, decision framework
├── sql/
│   └── FAGL_SQL_Playbook.sql            # Schema and 20+ queries (EDA, anomaly detection, rolling metrics)
├── powerbi/
│   └── FAGL_Reliability_Dashboard.pbix  # Power BI dashboard (DAX measures, slicers, drill-through)
├── data/
│   └── fagl_weekly_reliability_data.csv # 104-week event-driven synthetic dataset
└── charts/
    └── wk_chart*.png                    # EDA visuals generated directly from the dataset

```

*Note: For the deep dive into the engineering context, root cause analysis (Fishbone/5 Whys), and full financial methodology, read `reports/FAGL_Final_Project_Report.md`.*

## Data Provenance: Real vs. Synthetic

Before interpreting the metrics, it is critical to distinguish between actual field data and synthetic/illustrative modeling used for this analytics build:

* **Real Data (Anchors):** The well parameters (1,300–2,600 SCMD gas, 10–20 m³/day water, FBHP ~25 psi) and the core failure rate: **26 pump trips and 7 workovers in the most recent 4-month window**. The root cause (coal fines abrasion) is also factual.
* **Synthetic Data:** The full 104-week time series and the Fines Proxy Index. The dataset was generated to realistically model Poisson-distributed failures, escalation-based workovers, and post-repair honeymoon periods anchored to the real 4-month failure rate.
* **Illustrative Financials:** All cost and breakeven figures (e.g., rig day rates, gas prices, FAGL capex) are illustrative methodologies built to demonstrate financial logic. No proprietary financial data was used or disclosed.

## Analytics Methodology Highlights

1. **Business Reframing:** Shifted the engineering question from production optimization (the well is not lift-constrained) to a **reliability-driven capital allocation decision**.
2. **Exploratory Data Analysis:** Analyzed 104 weeks of jagged, event-driven data using statistical process control (Z-score anomaly detection) and rolling averages to identify underlying deterioration amidst high weekly volatility.
3. **Root Cause & Pareto Analysis:** Separated trips from workovers to prove that high-frequency events (trips) are an operational nuisance, but low-frequency events (workovers) are the true financial drain.
4. **Stress-Tested Decision Framework:** Replaced subjective scoring with a weighted decision matrix subjected to Monte Carlo sensitivity analysis to ensure the recommendation (Pilot FAGL, then scale) was mathematically robust against shifting priorities.
5. **Financial Justification:** Built a reproducible cost-avoidance formula evaluating maintenance run-rate against incremental capex/opex to determine an illustrative breakeven period.
