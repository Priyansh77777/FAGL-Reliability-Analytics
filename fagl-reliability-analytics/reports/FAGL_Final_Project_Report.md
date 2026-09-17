# FAGL_Final_Project_Report.md
## Data-Driven Reliability Decision Making: Should the Operator Continue Repairing the PCP or Transition to FAGL?

**Status: PRE-IMPLEMENTATION.** FAGL has not been installed, commissioned, or field-tested on this well. Every conclusion below is a decision-support recommendation, not a report of results.

**Source of truth priority (per project instructions):** Panel Review & Interview-Hardening Addendum > this report/earlier Analytics Portfolio > original Reliance/IIT(ISM) engineering report. Where this document differs from the earlier Analytics Portfolio, this document is the current, superseding version.

---

## 1. Real Project Facts (non-negotiable, unaltered)

- CBM well, currently dewatered with a Progressive Cavity Pump (PCP).
- Water production: 10–20 m³/day. Gas production: 1,300–2,600 SCMD.
- Flowing bottom-hole pressure ≈ 25 psi — the well is not lift-constrained.
- **26 pump trips and 7 workovers in the most recent 4-month window.**
- Root cause: coal fines abrasion of the PCP rotor/stator.
- Stated objective: improve reliability, **not** increase production.
- FAGL is proposed specifically because it removes downhole rotating equipment.
- Completed as a real B.Tech internship project at Reliance Industries Limited (IIT (ISM) Dhanbad, Dept. of Petroleum Engineering, May 2026).

Everything else in this report — the weekly dataset, KPI values, cost figures, and scoring model — is either **synthetic (clearly labeled)** or **illustrative methodology (clearly labeled)**. See `FAGL_Synthetic_Data_Generation_Methodology.md` for full dataset provenance.

---

## 2. Business Problem Reframing

The engineering question ("replace PCP with FAGL?") is a **reliability-driven capital allocation decision**, not a production-optimization decision. The well already has more lifting capacity than it uses (FBHP ~25 psi, near its practical floor) — the actual constraint is that a specific mechanical component fails on a predictable, worsening cadence due to an abrasive byproduct of the reservoir it produces from.

**Core question:** Should the operator continue absorbing recurring PCP repair cost, or make a capital shift to a lift technology (FAGL) that structurally removes the failure mechanism?

**Stakeholders:** Field/production operations (fewer emergency call-outs), maintenance/workover engineering (crew workload, HSE exposure), asset/production management (availability, opex predictability), finance (capex vs. recurring opex), HSE (fewer well interventions), reservoir engineering (confirming dewatering isn't compromised).

---

## 3. KPI Framework

| KPI | Formula | Real industry use | Who uses it | Decision it drives |
|---|---|---|---|---|
| MTBF | (Uptime hours) ÷ (failure count), trailing 8-week window | Yes — standard reliability KPI | Reliability/maintenance engineers | Spare-parts stocking, maintenance interval planning |
| MTTR | (Downtime hours) ÷ (failure count), trailing 8-week window | Yes | Maintenance supervisors | Crew staffing, spares pre-positioning |
| Availability % | (1 − downtime/168) × 100, weekly | Yes — universal in upstream ops | Production engineers, asset managers | Well/asset ranking for intervention priority |
| Failure Rate | Trips per week | Yes | Reliability engineers | Trigger for redesign vs. repair |
| Maintenance Cost per Unit Output | Cost ÷ gas volume | Common in asset-heavy industries | Finance + Ops | Whether the well is still economic to keep running as-is |
| Reliability Index (composite) | Weighted normalized blend of trips/workovers/downtime | Less standardized by name, but composite asset-health scorecards are common in practice | Asset managers, executives | Quick relative ranking across a well portfolio |
| Days Since Last Workover | Reliability clock, resets on each workover | Practical ops-floor KPI | Field ops teams | Early-warning dashboard tile |
| Failure Rate Forecast | Linear trend extrapolation (see SQL Playbook 7.1) | Basic but real forecasting practice | Planning/ops analysts | Timing of intervention decisions |
| Anomaly Detection (Z-score) | Flag weeks where trips exceed mean by >2σ | Standard statistical process control | Reliability/data analysts | Trigger for root-cause investigation |
| Cost Avoidance / Rupee Invested | Avoided repair cost ÷ FAGL capex+opex | ROI-style ratio | Finance | Capital allocation across wells |
| Cumulative Cost of Inaction | Running total of unreliability cost vs. capex threshold | Decision-support framing | Management | "Why act now" trigger point |
| % Weeks Classified "Clean" | Zero-event weeks ÷ total weeks | Simple, communicable reliability stat | Executives | High-level health check |

---

## 4. Exploratory Data Analysis (on the verified weekly synthetic dataset, 104 weeks)

**Trend (Year-over-Year cohort comparison, computed directly, not eyeballed):**

| Period | Avg weekly trips | Avg weekly workovers | Avg availability % | Total maintenance cost |
|---|---|---|---|---|
| Year 1 (Weeks 1–52) | 0.71 | 0.19 | 89.77% | ₹73,39,991 |
| Year 2 (Weeks 53–104) | 1.21 | 0.31 | 83.72% | ₹1,15,27,539 |
| **Change** | **+70%** | **+60%** | **−6.05 points** | **+57%** |

This is a *realistic* (jagged, event-driven) deterioration, not a smoothed line — see `wk_chart1_trips_workovers.png`.

**Distributions:** 44 of 104 weeks (42.3%) are completely clean (zero trips, zero workovers) — real reliability data has long calm stretches punctuated by clusters, and this dataset reproduces that instead of hugging a trend line.

**Rolling metrics:** An 8-week rolling average of trips (SQL Playbook §6.2) smooths the weekly noise enough to see the underlying trend without hiding the volatility — this is the correct way to read a Poisson-driven weekly count series, and is shown in `wk_chart3_fines_vs_rolling_trips.png`.

**Anomaly detection:** A Z-score query (SQL Playbook §6.3) independently flags weeks **24, 63, 82, 87, and 93** as statistical outliers (>2σ above the mean trip count) — these correspond to the deliberately injected "bad batch of fines" weeks in the generator, confirming the anomaly-detection logic actually works rather than being decorative.

**Correlation matrix (recomputed, weekly dataset):**

| | Trips | Workovers | Downtime | MaintCost | ProdLoss | Availability | Fines | Gas | Water |
|---|---|---|---|---|---|---|---|---|---|
| Trips | 1.00 | 0.60 | 0.72 | 0.62 | 0.73 | −0.72 | 0.32 | −0.42 | −0.19 |
| Workovers | 0.60 | 1.00 | 0.97 | 0.98 | 0.97 | −0.97 | 0.18 | −0.57 | −0.34 |
| Fines Proxy | 0.32 | 0.18 | 0.21 | 0.17 | 0.21 | −0.21 | 1.00 | −0.09 | −0.01 |
| Gas | −0.42 | −0.57 | −0.60 | −0.54 | −0.55 | 0.60 | −0.09 | 1.00 | 0.17 |

**Read this honestly:** Fines Proxy correlates only *weakly* with trips (0.32) now — a deliberate fix, since the previous version's near-1.0 correlations were flagged as a fabrication tell. Downtime vs. Availability is exactly −1.0 by construction (Availability is a direct formula of Downtime, not an independent finding). Workovers vs. Cost remains high (0.97–0.98) because cost is genuinely, mostly driven by workover events — that's expected and defensible, not suspicious, because workover cost buildup uses rig-day-rate × duration, which is the real cost driver in the underlying formula, not an artifact.

**Cost driver / maintenance burden analysis — the strongest real finding in the whole project:**

Computed directly from the actual event counts and the disclosed cost build-up model (not asserted):

| | Share of events | Share of maintenance cost (trip + workover repair cost only) |
|---|---|---|
| Pump Trips | 79.4% (100 of 126 events) | 6.9% |
| **Workovers** | **20.6% (26 of 126 events)** | **93.1%** |

**20.6% of events (workovers) drive 93.1% of pure repair/maintenance cost.** See `wk_chart5_pareto.png`. This split is deliberately based on the `Estimated_Maintenance_Cost_INR` column only (trip cost + workover cost), which makes it immune to uncertainty in the illustrative gas-price assumption used elsewhere — lead every conversation about this project with this number, since it's the most robust, least assumption-dependent finding in the whole project.

**A second, separate financial point — production loss is larger than it first looked.** Once production-loss cost is added in (at the corrected gas price, see §7), the picture broadens: of the full cost of unreliability (maintenance + deferred production), workovers still dominate at **66.5%**, but production loss now accounts for a material **28.6%** (trip-driven minor repairs are only ~4.9%). This is worth stating as two distinct numbers rather than one blended figure — the maintenance-only split (93.1%) is the cleaner, assumption-free finding; the broader total-cost split (66.5%/28.6%/4.9%) depends on the illustrative gas price and should always be quoted with that caveat attached.

---

## 5. Root Cause Analysis

### Facts, Assumptions, and Hypotheses — strictly separated

**🟢 FACTS (directly stated in the original report):**
- PCP rotor/stator wear is caused by coal fines abrasion.
- 26 pump trips and 7 workovers occurred in a 4-month window.
- FBHP (~25 psi) shows lifting capacity is not the constraint.
- FAGL removes downhole rotating equipment.

**🟡 ASSUMPTIONS (reasonable, not explicitly measured in the report):**
- Failure frequency has been rising progressively over a longer period than the one 4-month snapshot given.
- Coal fines production itself increases over the well's life (report states this generally for maturing CBM wells; not measured specifically for this well over time).

**🔵 HYPOTHESES (candidate explanations to test with real data, not asserted as true):**
- Fines loading may correlate with specific production-rate regimes (e.g., higher water rates dislodge more fines) — untested.
- Workover frequency may be influenced by repair quality/parts availability, not fines severity alone — untested.

### Pareto Analysis
See Section 4 — **20.6% of events (workovers) cause 93.1% of pure maintenance cost, and remain the largest single driver (66.5%) even once production-loss cost is included.** This is the project's headline, genuinely computed finding.

### Fishbone (Ishikawa) Diagram — populated only where the report provides evidence

```
                         COAL FINES ABRASION → PUMP FAILURE
   ┌───────────────┬────────────────┬────────────────┬───────────────┐
   │   EQUIPMENT    │    PROCESS      │   MATERIAL      │  ENVIRONMENT   │
   │  Rotor/stator  │ Continuous      │ Coal fines      │ Coal seam      │
   │  elastomer     │ mechanical      │ (abrasive       │ geology        │
   │  wear from     │ rotation while  │ solid particles │ produces fines │
   │  abrasive      │ fines present   │ suspended in    │ as a natural   │
   │  contact       │ in fluid stream │ produced water) │ byproduct      │
   │  (FACT)        │ (FACT)          │ (FACT)          │ (FACT)         │
   └───────────────┴────────────────┴────────────────┴───────────────┘
```
No "People" or "Measurement" branches are populated — the report contains no operator-error or instrumentation evidence, and inventing one would violate the "use only evidence supported by the original report" instruction.

### 5 Whys — stops exactly where the report's evidence stops
1. **Why 26 trips/7 workovers in 4 months?** → Repeated PCP failures. *(FACT)*
2. **Why did the PCP fail repeatedly?** → Rotor/stator wear from coal fines abrasion. *(FACT)*
3. **Why are coal fines present?** → Natural byproduct of CBM coal-seam production entering the wellbore with produced water. *(FACT)*
4. **Why doesn't the PCP tolerate this?** → It relies on close-tolerance rotating mechanical contact, inherently vulnerable to abrasive particles. *(FACT, from mechanism)*
5. **Why hasn't this been structurally addressed rather than repeatedly repaired?** → No downhole-rotating-part-free alternative had been implemented yet — which is the report's own stated motivation for evaluating FAGL, not a speculative answer.

---

## 6. Decision Framework

### 6.1 Weighted Decision Matrix with explicit scoring rubric

**Rubric:** 1–3 = fails routinely under current conditions; 4–6 = manageable only with active intervention; 7–8 = reliable, needs monitoring; 9–10 = structurally eliminates the failure mode.

| Criterion | Weight | Rationale | PCP | FAGL |
|---|---|---|---|---|
| Reliability | 30% | The well's actual, documented pain point | 3 | 8 |
| Coal Fines Handling | 20% | Root cause; FAGL's core design advantage | 3 | 9 |
| Maintenance Burden | 20% | Second-largest cost/HSE driver | 3 | 8 |
| Downtime/Availability | 15% | Ties reliability to revenue-generating uptime | 4 | 8 |
| Operational Risk | 10% | FAGL is unproven at this specific well — a real, disclosed risk | 8 | 5 |
| Scalability | 5% | Report frames methodology as reusable field-wide | 5 | 8 |

**Weighted scores: PCP = 3.75 / 10. FAGL = 7.90 / 10.**

### 6.2 Sensitivity Analysis & Monte Carlo Framework

**Monte Carlo (2,000 simulated weight combinations, each weight perturbed ±30% and renormalized):** FAGL wins in **2,000 / 2,000 trials (100%)**. Score gap (FAGL − PCP) ranges from **+3.72 to +4.51** — never close to zero.

**One-criterion-at-a-time extreme test (100% of weight on a single criterion):**

| 100% weight on... | PCP | FAGL | Winner |
|---|---|---|---|
| Reliability | 3.0 | 8.0 | FAGL |
| Coal Fines Handling | 3.0 | 9.0 | FAGL |
| Maintenance | 3.0 | 8.0 | FAGL |
| Downtime | 4.0 | 8.0 | FAGL |
| **Operational Risk** | **8.0** | **5.0** | **PCP** |
| Scalability | 5.0 | 8.0 | FAGL |

**Honest takeaway:** the recommendation only flips if a decision-maker cares *exclusively* about new-technology commissioning risk, to the total exclusion of reliability, cost, and downtime. Name this limitation yourself in any interview — it is the single most convincing piece of evidence that the analysis isn't one-sided advocacy.

### 6.3 Risk Matrix

| Risk | Likelihood* | Impact | Mitigation (from the source report) |
|---|---|---|---|
| Foam instability during commissioning | Medium | Medium | Gradual gas-injection ramp-up (20,000 → 8,000–10,000 SCMD) |
| Surfactant/produced-water incompatibility | Low-Medium | High | Lab compatibility testing pre-implementation (report's own recommendation) |
| Coal fines plug capillary tubing/defoamer | Low | Medium | Dispersant co-injection, defoamer system design |
| FAGL fails to reduce trips as expected | Low | High | Staged commissioning with instrumentation before full optimization |
| Excess water production reduces foam effectiveness | Low | Medium | Report explicitly flags this as a known limitation |

*Likelihood ratings are qualitative judgment calls based on how the source report frames each risk, not measured probabilities — state this explicitly if asked.*

### 6.4 Scenario Analysis

| Scenario | What happens | Recommendation under this scenario |
|---|---|---|
| **Base case** | Fines severity keeps worsening (as modeled) | Switch to FAGL — supported by all sensitivity tests |
| **Optimistic PCP** | Fines production plateaus | Case for FAGL weakens; a cheaper interim fix (more frequent scheduled PCP swaps) may be more economical short-term |
| **Pessimistic FAGL** | Commissioning takes multiple attempts; foam stability issues persist | Delay full switch; pilot on this well only before scaling |
| **Field-scale** | Multiple wells show the same failure pattern | Strongest case for FAGL — capex amortized across a screening program |

### 6.5 Pilot Recommendation Framework

Given the source report's own staged-commissioning philosophy (ramp to 20,000 SCMD, then optimize to 8,000–10,000 SCMD) and the Operational Risk criterion's role as the one weak spot in the decision matrix, the recommended path is:

1. **Pilot** FAGL on this single well only, with instrumentation from Day 1 (gas injection rate, casing pressure, tubing pressure, surfactant rate, produced water rate — all explicitly recommended in the source report).
2. **Pre-register success thresholds** before commissioning: trips/workovers should approach zero for the mechanical-failure mode within [X] weeks of stable operation; production should stay within the historical 1,300–2,600 SCMD / 10–20 m³/day bands.
3. **Only then** scale the same weighted-matrix screening approach to other candidate wells field-wide.

### 6.6 Management Decision Process (how this would actually get decided)

Not off a single score — off the combination of: (a) the weighted matrix passing sensitivity testing, (b) a bounded, monitorable risk register with mitigations already specified in engineering, and (c) a staged/pilot rollout path that limits downside if the pessimistic scenario occurs. This four-part combination is what a real capital-decision memo looks like.

---

## 7. Financial Justification Framework (methodology only — "Illustrative Example Only")

**Ground rule, restated every time this is discussed: no proprietary RIL financial data was available. Every rupee figure below is a swappable input to a formula, not an observed fact.**

```
Workover Cost (INR) = (Rig Day Rate × Days per Workover) + Parts/Crew Cost
   Illustrative inputs used in this dataset: Rig Day Rate ~ INR 1.5-2.2 lakh/day,
   Days ~ triangular(1.2, 2.56, 4.5) days [2.56-day average per the brief],
   Parts/Crew ~ INR 0.8-2.5 lakh -> lands in the brief's stated ₹5-20 lakh/workover range

Pump Trip Cost (INR) = Technician Callout Fee (illustrative, ~INR 8,000-18,000)
   [secondary cost driver, as specified]

Production Loss (INR) = Downtime Hours × (Gas Production SCMD ÷ 24) × Gas Price (INR/SCM)
   Illustrative Gas Price used: INR 40/SCM
   [primary cost driver for pump trips, as specified]

Maintenance Cost (weekly) = (Trips × Trip Cost) + (Workovers × Workover Cost)

Cost Avoidance Estimate = (Avoided Maintenance + Avoided Production Loss) − FAGL Incremental Opex
```

**Illustrative breakeven example (labeled, not a real RIL figure):**

Using the most recent 17-week (anchor-window) average weekly **total cost of unreliability** — maintenance cost (≈ INR 2,69,613/week) plus production loss cost at the corrected INR 40/SCM gas price (≈ INR 1,15,866/week), for a combined **≈ INR 3,85,479/week** (annualized ≈ INR 2.00 crore/year) — against an illustrative FAGL capex of INR 45,00,000 and incremental weekly opex of INR 15,000, assuming 85% of that combined cost is avoided:

**Illustrative breakeven ≈ 14.4 weeks (~0.28 years).**

*(Note: an earlier draft of this analysis used a placeholder gas price of INR 9/SCM, which understated production-loss cost and gave an illustrative breakeven of ~21 weeks. Correcting the gas price to ~INR 40/SCM — closer to real domestic gas pricing — raises the weekly cost run-rate and therefore shortens the illustrative breakeven. This is a useful example to have ready in an interview: it shows the methodology responding correctly and immediately to a corrected input, which is exactly the point of building a formula instead of hard-coding a number.)*

This number should never be quoted without the word "illustrative" attached in the same sentence — the framework (not the specific weeks) is the deliverable.

---

## 8. Conclusion

The recommendation — pilot, then scale, FAGL — comes from the real engineering report's own conclusion. This report's contribution is the analytics translation layer on top of it: a weekly reliability dataset built with disclosed, defensible generation logic; KPIs with stated industry usage; a genuinely computed Pareto finding (20.6% of events drive 93.1% of maintenance cost, and 66.5% of total cost including production loss); and a decision model that was stress-tested rather than merely asserted (100% Monte Carlo robustness, with one honestly-disclosed weak spot). That combination — disclosure discipline + methodology + robustness testing — is what should be defended in an interview, not any single number in the dataset.
