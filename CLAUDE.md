# LEGO Collectibles Portfolio Optimization

## Owner & Purpose
Jeffrey Lee — Emory BBA/MAcc '28. This is a public GitHub portfolio piece for
consulting recruiting (target: shippable by Fall 2026). Audience is an MBB/finance
interviewer who spends 90 seconds on it. Judge every decision against that.

## The Question
Given a budget of $X, what is the optimal LEGO portfolio — and how much of the
classic portfolio toolkit (risk, value, diversification, robustness) actually
survives contact with an illiquid, indivisible, thin-data asset class?

Output: actual allocations at three budgets, an efficient frontier, an honest
Sharpe accounting, and a verdict. A conclusion of "the optimizer says don't"
is a valid and preferred finding over a suspiciously bullish one.

## Final Deliverable
A rendered Quarto report (`report.qmd` → GitHub Pages) whose README is the
front door. ~8-12 pages. FIVE charts, no more:
1. Matched-set index, nominal vs. CPI-deflated
2. Correlation heatmap across theme-group sub-indices
3. Efficient frontier, with and without the indivisibility constraint
4. Allocations by budget level
5. Sharpe waterfall (naive → unsmoothed → after transaction costs)

Structure: verdict on page one, not page nine.

## Data (already verified — do not re-litigate)

`data/raw/lego_data_price_history.xlsx` — 185,996 rows × 3 cols
  - `Date` (monthly string, "2018-06" → "2023-06", 61 months)
  - `Price` (PLN, aftermarket, promoklocki.pl)
  - `url` (promoklocki.pl set URL)

`data/raw/lego_brickset.xlsx` — 19,785 rows × 35 cols
  - Key: `number` (set number), `theme`, `themeGroup`, `subtheme`, `pieces`,
    `minifigs`, `year`, `US_retailPrice`, `availability`, `category`,
    `rating`, `reviewCount`, `ownedBy`, `wantedBy`

Source: Oczkoś, Podgórski, Szczepańska & Boiński (2024), Data in Brief 52:110056.
CC BY 4.0. Retrieved from github.com/BartekPodgorski/Lego_Predict.
See `data/raw/SOURCE.md`.

**Verified merge path:** extract set number from URL with regex
`/lego-[a-z0-9-]*?-(\d{4,7})-`, join to `brickset$number` as character.
→ 99.9% match rate. Yields **150,952 set-month obs, 7,005 sets, 61 months,
124 themes**. Coverage: pieces 98%, US_retailPrice 87%, minifigs 72%.
3,203 sets have ≥24 months; 1,830 have ≥36.

## The Four Data Problems (each must be solved in 01_clean.R)

1. **Duplicate set-months.** 2,097 url-Date pairs have >1 row (up to 25).
   Cause: minifigure series price each figure separately under one set URL.
   Fix: aggregate to mean price per set-month.

2. **Bad prices.** 11,156 obs are ≤0 or absurd (max observed: 99,999).
   Fix: filter to 0 < Price < 50000.

3. **Composition drift / survivorship.** Sets observed per month:
   793 (2018-06) → 2,558 (2021-06) → 974 (2023-06). Panel is unbalanced at
   BOTH ends. **Therefore the index MUST be matched-set / repeat-sales.
   NEVER a cross-sectional mean** — composition change would masquerade as
   returns. This is the Goetzmann / Bailey-Muth-Nourse problem.

4. **PLN denomination + Polish inflation.** Prices are złoty. Poland's 2022 CPI
   spiked ~17%. Deflating by Polish CPI (GUS or FRED, free) is **the single most
   important analytical decision in the project**. Report nominal AND real.

## Key Empirical Findings (verified — build on these, don't rediscover)

- **There is no 2022 crash in LEGO.** Crude chained matched-set index runs
  100 → 263 nearly monotonically, climbing *through* 2022 while Pokémon and
  sneakers collapsed. The original "2022 correction as stress test" plan is dead.
- **The replacement framing:** why did LEGO not crash when other collectibles did?
  That is a segmentation/diversification story — exactly the Masset & Weisskopf
  thesis. The stress test is now Poland's 2022 inflation spike, which forces the
  real-vs-nominal question. Much of that 163% is likely złoty inflation.
- **Sub-index correlations are genuinely low.** Educational vs. Action/Adventure
  0.06; Historical vs. Junior 0.05. The intra-asset-class diversification thesis
  has support in this data. This is the paper.
- Annualized vol by theme group ranges ~10% (Licensed) to ~22% (Junior).

## Sub-Indices
Theme groups with adequate coverage: Model making, Licensed, Basic, Junior,
Action/Adventure, Educational, Historical. Target 5-7. Mirrors Dobrynskaya &
Kishilova's 44-theme framing.

## Pipeline / Stage Plan

**Discipline: get an ugly-but-complete end-to-end pipeline running FIRST
(crude index + continuous weights), then upgrade each stage.** Most student
projects die perfecting stage 2 and never reach stage 5. Scope creep is the
#1 risk to this project.

- `R/01_clean.R` (6-10 hrs) — dedup → filter → parse setnum → merge →
  one tidy panel to `data/processed/panel.rds`
- `R/02_index.R` (8-12 hrs) — matched-set hedonic index per theme group via
  `fixest` (log price ~ pieces + minifigs + theme + availability + month FE),
  then CPI-deflate. HARDEST CONCEPTUAL STAGE. Fallback: crude chained
  matched-set index (mean of per-set log diffs, cumsum, exp).
- `R/03_returns.R` (6-8 hrs) — returns, Getmansky-Lo-Makarov unsmoothing,
  covariance with Ledoit-Wolf shrinkage
- `R/04_optimize.R` (10-15 hrs) — `ompr` + ROI + GLPK. Integer + budget +
  cardinality constraints. Budgets: $2K / $10K / $50K. Frontier both with and
  without indivisibility. RISKIEST STAGE (solvers eat weekends).
  Fallback: continuous weights + post-hoc rounding, disclosed as approximation.
  If quadratic risk fights GLPK, linearize to MAD/CVaR to keep it a MILP.
- `report.qmd` (8-12 hrs) — the write-up. Do not shortchange this; recruiters
  are evaluating exactly this skill.

## Why Indivisibility Is The Original Contribution
LEGO sets are integer-quantity, lumpy goods. A $50 City set and an $800 UCS
Millennium Falcon in one budget is textbook lumpiness that vanilla Markowitz
doesn't handle. The gap between the constrained and unconstrained frontier IS
the contribution. Show how optimal portfolio shape changes as lumpiness binds
across the three budget levels — that's the headline chart.

## Citations (all verified)
- Dobrynskaya, V. & Kishilova, J. (2022). LEGO — The Toy of Smart Investors.
  *Research in International Business and Finance*, 59, 101539.
  → LEGO ~11% nominal / 8% real returns, Sharpe ~0.4, 2,322 sets, 1987-2015.
- Oczkoś, W., Podgórski, B., Szczepańska, W., & Boiński, T. M. (2024).
  *Data in Brief*, 52, 110056. → the data source.
- Dimson, E. & Spaenjers, C. (2014). Investing in Emotional Assets.
  *Financial Analysts Journal*, 70(2), 20-25. → collectibles beat bonds/gold,
  lose to equities, higher true vol, high transaction costs.
- Masset, P. & Weisskopf, J.-P. (2010). Raise Your Glass: Wine Investment and
  the Financial Crisis. SSRN 1457906. → segmentation → diversification.
- Getmansky, M., Lo, A. W. & Makarov, I. (2004). *JFE*, 74(3), 529-609.
  → unsmoothing illiquid returns; smoothing-adjusted Sharpe.
- Chang, Meade, Beasley & Sharaiha (2000). *Computers & Operations Research*,
  27(13), 1271-1302. → cardinality-constrained portfolios are NP-hard MIQP.
- Shanaev et al. (2020). *Journal of Risk Finance*, 21(5), 577-620.
  → the skeptical counterweight. Cite for balance.
- Goetzmann (1992); Bailey, Muth & Nourse (1963) → repeat-sales index methods.

## Repo Layout
```
data/raw/       # sacred. NEVER edit, NEVER write here. SOURCE.md lives here.
data/processed/ # script outputs (panel.rds, indices.rds)
R/              # 01_clean.R ... 04_optimize.R
figures/        # the five charts
output/         # rendered report
report.qmd
README.md       # problem → method → 2 headline charts → findings → reproduce
renv.lock
CLAUDE.md
```

## Stack
tidyverse, readxl, fixest, PerformanceAnalytics, ompr + ompr.roi + ROI +
ROI.plugin.glpk, scales, renv, Quarto. R chosen over Python: the finance
package ecosystem is better and Quarto gives the deliverable directly.

## Working Agreement
- Owner is a beginner in R. Explain what code does and why, inline. The
  cleaning script doubles as the R tutorial.
- One stage at a time. Working end-to-end beats perfect-and-unfinished.
- Prefer honest findings over flattering ones. Report CIs. Covariance on thin
  data is genuinely unreliable — indices mitigate, they don't fix.
- Do not scrape. Do not add data sources. The universe is fixed.
- Commit after each stage.

## Explicitly Out of Scope for v1
Pokémon/cards, multi-category covariance, live APIs, transaction-cost
optimization, factor models, Shiny (Quarto first; Shiny is a possible v2).
