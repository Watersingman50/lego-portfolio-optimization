# 01_clean.R
# Cleans and merges the LEGO price history and set characteristics data.
# Input:  data/raw/lego_data_price_history.xlsx, data/raw/lego_brickset.xlsx
# Output: data/processed/panel.rds

library(tidyverse)
library(readxl)

prices <- read_excel("data/raw/lego_data_price_history.xlsx")
sets   <- read_excel("data/raw/lego_brickset.xlsx")

# Problem 1: collapse duplicate set-months (minifig series priced per-figure)
prices_clean <- prices |>
  group_by(url, Date) |>
  summarize(Price = mean(Price), .groups = "drop")

# Problem 2: drop unrealistic prices
prices_clean <- prices_clean |>
  filter(Price > 0, Price < 50000)

# Problem 3: extract the LEGO set number from the url
matches <- str_match(prices_clean$url, "-(\\d{4,7})-")
prices_clean$setnum <- matches[, 2]

# Problem 4: one row per set number in the characteristics table
# (keep the lowest numberVariant, since minifig-series sets have one
# row per individual figure sharing the same base set number)
set_clean <- sets |>
  mutate(setnum = as.character(number)) |>
  arrange(numberVariant) |>
  distinct(setnum, .keep_all = TRUE)

# Merge prices to characteristics
merged <- prices_clean |>
  left_join(set_clean, by = "setnum")

# Drop rows that never matched a set
merged <- merged |>
  filter(!is.na(theme))

# Save the clean panel
dir.create("data/processed", showWarnings = FALSE)
saveRDS(merged, "data/processed/panel.rds")

cat("Final panel:", nrow(merged), "rows\n")