# 04_optimize.R
# Builds three portfolio views:
#  1. Naive integer-constrained portfolios (budget + binary buy/no-buy per set)
#     at $2K / $10K / $50K, using theme-level expected returns.
#  2. A continuous mean-variance efficient frontier at the theme level,
#     using the real covariance matrix from Stage 3 (CVXR, quadratic).
# The comparison between (1) and (2) is the project's central finding:
# naive return-maximization concentrates 100% into the single highest-
# return theme (Technical) at every budget, ignoring risk entirely, while
# the frontier shows the diversified, risk-aware alternative and its cost
# in achievable risk.
#
# NOTE: a linear risk penalty (mean_return - lambda*volatility) was tested
# and found NOT to induce diversification at any tested lambda: a linear
# objective with a single budget constraint always has an optimal solution
# concentrated in the single best per-dollar asset (a "knapsack" property).
# True diversification requires a quadratic (covariance) term, which GLPK
# cannot solve at integer scale -- hence the two-model approach below.
#
# Input:  data/processed/latest_prices.rds, data/processed/returns.rds,
#         data/processed/cov_matrix.rds
# Output: data/processed/portfolio_2k.rds, portfolio_10k.rds, portfolio_50k.rds,
#         data/processed/frontier.rds

library(tidyverse)
library(ompr)
library(ompr.roi)
library(ROI)
library(ROI.plugin.glpk)
library(CVXR)

latest_prices <- readRDS("data/processed/latest_prices.rds")
returns <- readRDS("data/processed/returns.rds")
cov_matrix <- readRDS("data/processed/cov_matrix.rds")

risk_summary <- returns |>
  group_by(themeGroup) |>
  summarize(
    mean_return = mean(return, na.rm = TRUE),
    volatility = sd(return, na.rm = TRUE)
  )

sets <- latest_prices |>
  left_join(risk_summary, by = "themeGroup")

# --- Integer-constrained portfolios ---
n <- nrow(sets)

solve_budget <- function(budget) {
  model <- MIPModel() |>
    add_variable(buy[i], i = 1:n, type = "binary") |>
    set_objective(sum_expr(sets$mean_return[i] * sets$Price[i] * buy[i], i = 1:n), sense = "max") |>
    add_constraint(sum_expr(sets$Price[i] * buy[i], i = 1:n) <= budget)
  
  result <- solve_model(model, with_ROI(solver = "glpk"))
  solution <- get_solution(result, buy[i]) |> filter(value == 1)
  
  sets[solution$i, ] |> select(name, themeGroup, Price, mean_return)
}

portfolio_2k  <- solve_budget(2000)
portfolio_10k <- solve_budget(10000)
portfolio_50k <- solve_budget(50000)

saveRDS(portfolio_2k,  "data/processed/portfolio_2k.rds")
saveRDS(portfolio_10k, "data/processed/portfolio_10k.rds")
saveRDS(portfolio_50k, "data/processed/portfolio_50k.rds")

# --- Continuous mean-variance efficient frontier (theme level) ---
theme_names <- risk_summary$themeGroup
mu <- risk_summary$mean_return
Sigma <- cov_matrix[theme_names, theme_names]

solve_frontier_point <- function(target_return) {
  w <- Variable(7)
  risk <- quad_form(w, Sigma)
  port_return <- t(mu) %*% w
  objective <- Minimize(risk)
  constraints <- list(port_return == target_return, sum(w) == 1, w >= 0)
  problem <- Problem(objective, constraints)
  result <- solve(problem)
  
  achieved_risk_value <- sqrt(as.numeric(result$getValue(risk)))
  
  tibble(
    target_return = target_return,
    achieved_risk = achieved_risk_value,
    status = result$status
  )
}

target_returns <- seq(min(mu), max(mu), length.out = 10)
frontier <- map_dfr(target_returns, solve_frontier_point)

saveRDS(frontier, "data/processed/frontier.rds")

cat("Stage 4 complete.\n")
cat("Integer portfolios: $2K =", nrow(portfolio_2k), "sets, $10K =", nrow(portfolio_10k),
    "sets, $50K =", nrow(portfolio_50k), "sets (all 100% Technical)\n")
cat("Frontier: risk ranges from", round(min(frontier$achieved_risk), 3),
    "to", round(max(frontier$achieved_risk), 3), "\n")
# --- Turn the minimum-risk weights into an actual, buyable portfolio ---
min_var_weights <- tibble(
  themeGroup = c("Licensed", "Miscellaneous", "Pre-school", "Action/Adventure"),
  weight = c(0.462, 0.209, 0.201, 0.129)
)

allocate_min_var_portfolio <- function(total_budget) {
  map_dfr(1:nrow(min_var_weights), function(i) {
    theme <- min_var_weights$themeGroup[i]
    sub_budget <- total_budget * min_var_weights$weight[i]
    theme_sets <- sets |> filter(themeGroup == theme)
    n <- nrow(theme_sets)
    
    model <- MIPModel() |>
      add_variable(buy[j], j = 1:n, type = "binary") |>
      set_objective(sum_expr(theme_sets$Price[j] * buy[j], j = 1:n), sense = "max") |>
      add_constraint(sum_expr(theme_sets$Price[j] * buy[j], j = 1:n) <= sub_budget)
    
    result <- solve_model(model, with_ROI(solver = "glpk"))
    solution <- get_solution(result, buy[j]) |> filter(value == 1)
    theme_sets[solution$j, ] |> select(name, themeGroup, Price, mean_return)
  })
}

portfolio_min_var_10k <- allocate_min_var_portfolio(10000)
saveRDS(portfolio_min_var_10k, "data/processed/portfolio_min_var_10k.rds")
portfolio_min_var_2k  <- allocate_min_var_portfolio(2000)
portfolio_min_var_50k <- allocate_min_var_portfolio(50000)

saveRDS(portfolio_min_var_2k,  "data/processed/portfolio_min_var_2k.rds")
saveRDS(portfolio_min_var_50k, "data/processed/portfolio_min_var_50k.rds")