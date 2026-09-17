# FAGL vs PCP Reliability Analytics
### Data-Driven Reliability Decision Making for a Coal Bed Methane Well

**Status: PRE-IMPLEMENTATION.** This is a decision-support analytics project, not a report of results. Foam Assisted Gas Lift (FAGL) has not been installed, commissioned, or field-tested on the well this project is based on.

## What this is

A real petroleum engineering feasibility study — *"Pre-Implementation Assessment of Foam Assisted Gas Lift (FAGL) in CBM Wells,"* completed during a B.Tech internship at Reliance Industries Limited (IIT (ISM) Dhanbad, Dept. of Petroleum Engineering) — reframed as a data analytics case study: a well is failing repeatedly (26 pump trips, 7 workovers in 4 months) because abrasive coal fines wear out its Progressive Cavity Pump. The core question: **keep repairing the PCP, or switch to a lift technology that removes the failure mechanism entirely?**

The engineering conclusion is the source report's own. This repo is the analytics layer built on top of it: a synthetic-but-anchored weekly dataset, a verified SQL analytics layer, a Power BI dashboard design, and a decision model stress-tested with Monte Carlo simulation rather than merely asserted.

## Repo structure

```
├── reports/
│   └── FAGL_Final_Project_Report.md          Business framing, KPIs, EDA, root cause analysis,
│                                               decision framework, financial justification
├── sql/
│   └── FAGL_SQL_Playbook.sql                  Schema, 20+ queries, all verified against a live DB
├── powerbi/
│   └── FAGL_PowerBI_Implementation_Guide.md   7 dashboards with DAX measures, slicers, drill-through
├── data/
│   └── fagl_weekly_reliability_data.csv       104 weeks, event-driven synthetic dataset
└── charts/
    └── wk_chart*.png                          EDA visuals generated directly from the dataset
```

**Read order:** `reports/FAGL_Final_Project_Report.md` first — it's the main narrative and links conceptually to everything else. `docs/` explains where the dataset came from before you trust any number in it. `sql/` and `powerbi/` are the implementation layers. `data/` and `charts/` are the artifacts everything else was computed from.

## The one number to lead with

**20.6% of failure events (workovers) drive 93.1% of pure maintenance cost** — computed directly from real event counts plus a disclosed, formula-based cost model, not an invented correlation. A broader total-cost view (including production loss, priced at an illustrative ~₹40/SCM) shows workovers still dominate at 66.5%, with production loss itself a material 28.6%.

## What's real vs. synthetic (read this before quoting any number)

- **Real:** the well, its production ranges (1,300–2,600 SCMD gas, 10–20 m³/day water), the flowing bottom-hole pressure (~25 psi), and — critically — **26 pump trips and 7 workovers in the most recent 4-month window**, which the weekly dataset's last 17 weeks are anchored to exactly.
- **Synthetic, clearly labeled throughout:** the full 104-week time series, the Fines Proxy Index, and every specific cost figure. See `docs/FAGL_Synthetic_Data_Generation_Methodology.md` for exactly how and why each column was generated.
- **Illustrative methodology, not real financial data:** all cost/breakeven figures. No proprietary Reliance Industries financial data was available or used.

## Reproducing the dataset

The dataset was generated with a fixed random seed and is fully reproducible (Poisson-distributed failures, escalation-based workovers, post-repair honeymoon periods, injected anomaly weeks).
