#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
})

if (!dir.exists(file.path("outputs", "logs"))) {
  dir.create(file.path("outputs", "logs"), recursive = TRUE)
}

files <- c(
  "data/samples/tw_list.csv",
  "data/samples/kr_list.csv",
  "data/samples/nk_list.csv"
)

required_cols <- list(
  "data/samples/tw_list.csv" = c("birth_year_roc","gender","ideology_raw","education_years","list_pride_treatment_indicator","list_pride_taiwan_count","direct_pride_taiwan","identity_category_raw"),
  "data/samples/kr_list.csv" = c("age","gender","education_raw","ideology_scale_raw","list_pride_count","direct_pride_korea","list_pride_treatment_arm","national_identity_strength"),
  "data/samples/nk_list.csv" = c("birth_year","gender","education_nk_raw","party_member_raw","year_defection","year_arrived_sk","unemployed_raw","list_sk_pride_treatment_arm","list_nk_pride_treatment_arm","list_sk_pride_count","list_nk_pride_count","direct_sk_pride","direct_nk_pride")
)

audit <- lapply(files, function(f) {
  d <- read_csv(f, show_col_types = FALSE)
  data.frame(
    file = f,
    n_rows = nrow(d),
    n_cols = ncol(d),
    n_complete_rows = sum(complete.cases(d)),
    stringsAsFactors = FALSE
  )
}) |> bind_rows()

col_check <- lapply(names(required_cols), function(f) {
  d <- read_csv(f, show_col_types = FALSE)
  miss <- setdiff(required_cols[[f]], names(d))
  extra <- setdiff(names(d), required_cols[[f]])
  data.frame(
    file = f,
    n_required_cols = length(required_cols[[f]]),
    n_missing_required_cols = length(miss),
    missing_required_cols = ifelse(length(miss) == 0, "", paste(miss, collapse = ";")),
    n_extra_cols = length(extra),
    stringsAsFactors = FALSE
  )
}) |> bind_rows()

na_summary <- lapply(files, function(f) {
  d <- read_csv(f, show_col_types = FALSE)
  tibble(file = f, column = names(d), na_prop = colMeans(is.na(d)))
}) |> bind_rows()

write_csv(audit, file.path("outputs", "logs", "data_audit_overview.csv"))
write_csv(col_check, file.path("outputs", "logs", "data_audit_columns.csv"))
write_csv(na_summary, file.path("outputs", "logs", "data_audit_missingness.csv"))

message("Wrote outputs/logs/data_audit_overview.csv")
message("Wrote outputs/logs/data_audit_columns.csv")
message("Wrote outputs/logs/data_audit_missingness.csv")
