# LEGO Aftermarket Portfolio Optimization

**[View the code](R/)** | **[Full report](report.html)** (open locally after cloning, or enable GitHub Pages to host it live)

Given a fixed budget, what does an optimal LEGO aftermarket portfolio actually look like, and how much of classic portfolio theory survives contact with an illiquid, indivisible, thin-data collectible market?

## Key findings

1. **Nominal price stability masked a real decline.** LEGO's złoty aftermarket price rose steadily from 2018 to 2023, but after adjusting for Polish inflation, real purchasing-power returns peaked in late 2021 and ended below the 2018 starting point by June 2023.
2. **LEGO theme groups do not diversify each other as well as expected.** Cross-theme correlations of 0.73 to 0.95 contradict the assumption that "collectibles" are internally diversified.
3. **A naive return-maximizing optimizer concentrates 100% of any budget into a single theme,** at $2K, $10K, and $50K alike. A properly risk-adjusted mean-variance frontier achieves a lower-volatility portfolio than any single theme held alone.

## Data

150,971 cleaned set-month price observations across 6,072+ LEGO sets, June 2018 to June 2023, from an openly licensed academic dataset:

> Oczkoś, W., Podgórski, B., Szczepańska, W., & Boiński, T. M. (2024). Data on LEGO sets release dates and worldwide retail prices combined with aftermarket transaction prices in Poland between June 2018 and June 2023. *Data in Brief*, 52, 110056. CC BY 4.0.

## Method

- **Price index:** matched-set hedonic regression (`fixest`), controlling for pieces, minifigure count, and theme, with a monthly fixed effect to avoid composition-drift bias from an unbalanced panel.
- **Inflation adjustment:** deflated using Poland's monthly CPI (FRED series `POLCPALTT01IXNBM`).
- **Illiquidity check:** tested for Getmansky-Lo-Makarov-style autocorrelation; found negative rather than positive autocorrelation, so the standard smoothing correction was not applied. Documented as a limitation.
- **Portfolio optimization:** compares a mixed-integer program (`ompr` + GLPK, budget and indivisibility constraints, set level) against a continuous quadratic mean-variance frontier (`CVXR`, theme level).

## Reproducing this analysis

```r
# Clone the repo, then in R:
install.packages("renv")
renv::restore()   # installs exact package versions used

source("R/01_clean.R")      # raw xlsx -> cleaned panel
source("R/02_index.R")      # hedonic index, CPI deflation, sub-indices
source("R/03_returns.R")    # returns, illiquidity check, covariance matrix
source("R/04_optimize.R")   # integer portfolios + efficient frontier

quarto::quarto_render("report.qmd")
```

## Project structure

```
data/raw/          Original source files (see SOURCE.md for provenance/license)
data/processed/    Cleaned panel, indices, returns, portfolios (regenerable via R/)
R/                 01_clean.R -> 04_optimize.R, run in order
report.qmd         Full analysis report
renv.lock          Exact package versions for reproducibility
```

## Limitations

See the "Honest limitations" section of the full report for a complete discussion, including the illiquidity-correction decision, the theme-level approximation for individual set returns, and the use of historical rather than live prices.

## Citations

- Dobrynskaya, V. & Kishilova, J. (2022). LEGO, The Toy of Smart Investors. *Research in International Business and Finance*, 59, 101539.
- Dimson, E. & Spaenjers, C. (2014). Investing in Emotional Assets. *Financial Analysts Journal*, 70(2), 20-25.
- Masset, P. & Weisskopf, J.-P. (2010). Raise Your Glass: Wine Investment and the Financial Crisis.
- Getmansky, M., Lo, A. W. & Makarov, I. (2004). An Econometric Model of Serial Correlation and Illiquidity in Hedge Fund Returns. *Journal of Financial Economics*, 74(3), 529-609.