# 03_returns.R
# Converts theme-group indices into returns, checks for illiquidity-driven
# autocorrelation (Getmansky-Lo-Makarov style), and computes the covariance
# matrix used as Stage 4's optimizer input.
# Input:  data/processed/sub_indices.rds
# Output: data/processed/returns.rds
#         data/processed/cov_matrix.rds

library(tidyverse)

sub_indices <- readRDS("data/processed/sub_indices.rds")

# --- Returns ---
returns <- sub_indices |>
  arrange(themeGroup, Date) |>
  group_by(themeGroup) |>
  mutate(return = Index / lag(Index) - 1) |>
  ungroup()

# --- Naive (pre-correction) risk/return summary ---
risk_summary <- returns |>
  group_by(themeGroup) |>
  summarize(
    mean_return = mean(return, na.rm = TRUE),
    volatility = sd(return, na.rm = TRUE)
  )

# --- Illiquidity check (Getmansky-Lo-Makarov style autocorrelation test) ---
# NOTE: Autocorrelation came back NEGATIVE for every theme (-0.09 to -0.35),
# not positive as classic smoothing/illiquidity bias would predict. This
# suggests month-to-month estimation noise (regression overreacting to thin
# sample composition) rather than appraisal-style smoothing. The standard
# GLM unsmoothing correction assumes positive autocorrelation and would be
# misapplied here, so we report RAW volatility and flag this as a documented
# limitation rather than force an inappropriate correction.
autocorrelation <- returns |>
  group_by(themeGroup) |>
  summarize(autocorrelation = cor(return, lag(return), use = "complete.obs"))

# --- Covariance matrix (Stage 4 optimizer input) ---
returns_wide <- returns |>
  select(themeGroup, Date, return) |>
  pivot_wider(names_from = themeGroup, values_from = return) |>
  select(-Date) |>
  drop_na()

cov_matrix <- cov(returns_wide)

saveRDS(returns, "data/processed/returns.rds")
saveRDS(cov_matrix, "data/processed/cov_matrix.rds")

cat("Stage 3 complete.\n")
print(risk_summary)
cat("\nAutocorrelation by theme (informing the no-GLM-correction decision):\n")
print(autocorrelation)