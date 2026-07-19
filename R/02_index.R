# 02_index.R
# Builds a hedonic price index (overall + theme-group sub-indices),
# deflates by Polish CPI, and computes cross-theme correlations.
# Input:  data/processed/panel.rds
# Output: data/processed/overall_index.rds
#         data/processed/sub_indices.rds
#         data/processed/correlation_matrix.rds

library(tidyverse)
library(fixest)

panel <- readRDS("data/processed/panel.rds")

# Handle missing predictors: minifigs=NA means genuinely zero;
# pieces=NA has no safe guess, so those rows are dropped.
panel <- panel |>
  mutate(minifigs = replace_na(minifigs, 0)) |>
  filter(!is.na(pieces))

# --- Overall nominal index ---
# Hedonic regression: price explained by pieces/minifigs/theme,
# with a separate fixed effect absorbed per month to avoid
# composition-drift bias (see CLAUDE.md problem #3).
model <- feols(log(Price) ~ pieces + minifigs + themeGroup | Date, data = panel)
month_effects <- fixef(model)$Date
nominal_index <- exp(month_effects - month_effects[1]) * 100

# --- CPI deflation ---
# Poland CPI, All Items, Monthly, NSA (FRED series POLCPALTT01IXNBM)
cpi_raw <- read_csv("https://fred.stlouisfed.org/graph/fredgraph.csv?id=POLCPALTT01IXNBM&cosd=2018-06-01&coed=2023-06-01",
                    show_col_types = FALSE)

cpi <- cpi_raw |>
  rename(cpi_raw_value = POLCPALTT01IXNBM) |>
  mutate(cpi_index = cpi_raw_value / cpi_raw_value[1] * 100,
         Date = format(observation_date, "%Y-%m"))

deflated <- tibble(Date = names(nominal_index), nominal_index = as.numeric(nominal_index)) |>
  left_join(cpi |> select(Date, cpi_index), by = "Date") |>
  mutate(real_index = nominal_index / cpi_index * 100)

saveRDS(deflated, "data/processed/overall_index.rds")

# --- Theme-group sub-indices ---
build_index <- function(theme_data) {
  m <- feols(log(Price) ~ pieces + minifigs | Date, data = theme_data)
  fe <- fixef(m)$Date
  exp(fe - fe[1]) * 100
}

major_themes <- c("Licensed", "Modern day", "Action/Adventure", "Miscellaneous",
                  "Model making", "Pre-school", "Technical")

sub_indices <- panel |>
  filter(themeGroup %in% major_themes) |>
  group_by(themeGroup) |>
  group_modify(~ tibble(Date = names(build_index(.x)),
                        Index = as.numeric(build_index(.x))))

saveRDS(sub_indices, "data/processed/sub_indices.rds")

# --- Correlation matrix ---
correlation_matrix <- sub_indices |>
  pivot_wider(names_from = themeGroup, values_from = Index) |>
  select(-Date) |>
  cor() |>
  round(2)

saveRDS(correlation_matrix, "data/processed/correlation_matrix.rds")

cat("Stage 2 complete.\n")
cat("Overall index: real_index ranges from", round(min(deflated$real_index),1),
    "to", round(max(deflated$real_index),1), "\n")
cat("Sub-indices built for", length(major_themes), "theme groups\n")