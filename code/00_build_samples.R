#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
})

root <- normalizePath(".", mustWork = FALSE)
raw_dir <- file.path(root, "data", "full_raw_archive")
out_samples <- file.path(root, "data", "samples")
out_dict <- file.path(root, "data", "dictionaries")

dir.create(out_samples, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dict, recursive = TRUE, showWarnings = FALSE)

required_raw <- c(
  file.path(raw_dir, "ROC24", "ROC Experiments 2023_February 15, 2024_02.14.csv"),
  file.path(raw_dir, "ROK23", "ROK 24.1 Experiments_May 7, 2024_09.24.csv")
)
missing <- required_raw[!file.exists(required_raw)]
if (length(missing) > 0) {
  stop("Missing raw archive files:\n", paste0("- ", missing, collapse = "\n"), call. = FALSE)
}

nk_candidates <- c(
  file.path(raw_dir, "NK", "IFES+2023+-+North+Koreans_October+23,+2023_08.57.csv"),
  file.path(raw_dir, "NK", "choice-text_IFES+2023+-+North+Koreans_October+23,+2023_09.46.csv")
)
nk_path <- nk_candidates[file.exists(nk_candidates)][1]
if (length(nk_path) == 0 || is.na(nk_path)) {
  stop(
    "Missing North Korean raw archive file. Expected one of:\n",
    paste0("- ", nk_candidates, collapse = "\n"),
    call. = FALSE
  )
}
nk_choice_path <- file.path(raw_dir, "NK", "choice-text_IFES+2023+-+North+Koreans_October+23,+2023_09.46.csv")

norm_num <- function(x) suppressWarnings(as.numeric(x))
`%||%` <- function(x, y) if (is.null(x)) y else x
is_true <- function(x) tolower(trimws(as.character(x))) %in% c("true", "1", "yes")

lookup_named <- function(x, key, default_value) {
  val <- x[key]
  if (length(val) == 0 || is.na(val[[1]])) default_value else unname(val[[1]])
}

infer_description <- function(nm, default_desc) {
  case_when(
    nm == "response_id" ~ "Respondent identifier from the source export.",
    str_detect(nm, "_raw$") ~ "Raw survey response value (verbatim coding).",
    str_detect(nm, "_count$") ~ "Numeric list-experiment count response.",
    str_detect(nm, "_treatment_arm$") ~ "List-experiment treatment-arm assignment from the survey flow.",
    str_detect(nm, "direct_") ~ "Direct-question response variable.",
    str_detect(nm, "birth|year|age") ~ "Age or year-based demographic variable.",
    str_detect(nm, "gender") ~ "Gender demographic variable.",
    str_detect(nm, "education") ~ "Education demographic variable.",
    str_detect(nm, "identity|national_identity") ~ "Identity or national-identity variable.",
    str_detect(nm, "list_") ~ "List-experiment variable.",
    TRUE ~ default_desc
  )
}

make_dictionary <- function(df, descriptions, used_in_script, default_desc) {
  tibble(
    variable = names(df),
    type = vapply(df, function(col) class(col)[1], character(1)),
    description = vapply(
      names(df),
      function(nm) lookup_named(descriptions, nm, infer_description(nm, default_desc)),
      character(1)
    ),
    used_in_script = vapply(
      names(df),
      function(nm) lookup_named(used_in_script, nm, "retained background/list context variable"),
      character(1)
    )
  )
}

# Taiwan ----------------------------------------------------------------------
tw_raw <- read_csv(
  file.path(raw_dir, "ROC24", "ROC Experiments 2023_February 15, 2024_02.14.csv"),
  show_col_types = FALSE
) |>
  slice(-c(1, 2)) |>
  filter(is_true(Finished))

tw <- tw_raw |>
  transmute(
    response_id = ResponseId,
    birth_year_roc = norm_num(Q1),
    gender = Q2,
    city_raw = Q3,
    ideology_raw = Q4,
    party_id_raw = Q5,
    residency_status_raw = Q6,
    cross_strait_preference_raw = Q28,
    identity_category_raw = Q28_2,
    direct_support_unification = Q29,
    direct_pride_taiwan = Q30,
    direct_pride_china = Q31,
    education_years = norm_num(Q32),
    employment_status_raw = Q33,
    work_type_raw = Q34,
    current_status_raw = Q35,
    home_language_raw = Q36,
    father_origin_raw = Q37,
    marital_status_raw = Q39,
    social_media_use_raw = Q40,
    follows_political_news_raw = Q41,
    main_news_source_raw = Q42,
    vote_2024_raw = Q43,
    social_class_raw = Q44,
    list_pride_treatment_indicator = norm_num(List1),
    list_independence_treatment_indicator = norm_num(List2),
    list_pride_treatment_arm = case_when(
      !is.na(FL_14_DO_FL_15) ~ "taiwan_pride_treatment",
      !is.na(FL_14_DO_FL_17) ~ "china_pride_treatment",
      !is.na(FL_14_DO_FL_19) ~ "control",
      TRUE ~ NA_character_
    ),
    list_independence_treatment_arm = case_when(
      !is.na(FL_22_DO_FL_23) ~ "independence_treatment",
      !is.na(FL_22_DO_FL_25) ~ "control",
      TRUE ~ NA_character_
    ),
    list_pride_taiwan_treatment_count = norm_num(Q10_1),
    list_pride_china_treatment_count = norm_num(Q10_2),
    list_pride_control_count = norm_num(Q10_3),
    list_pride_taiwan_count = dplyr::coalesce(list_pride_taiwan_treatment_count, list_pride_control_count),
    list_independence_treatment_count = norm_num(`Q11_1...120`),
    list_independence_control_count = norm_num(Q11_2)
  )

# South Korea -----------------------------------------------------------------
kr_raw <- read_csv(
  file.path(raw_dir, "ROK23", "ROK 24.1 Experiments_May 7, 2024_09.24.csv"),
  show_col_types = FALSE
) |>
  slice(-c(1, 2)) |>
  filter(!is.na(Q_RecaptchaScore))

kr <- kr_raw |>
  transmute(
    response_id = ResponseId,
    gender = `Q2...23`,
    region_raw = Q3,
    age = norm_num(`Q4...25`),
    education_raw = `Q5...26`,
    residency_status_raw = `Q6...27`,
    ideology_scale_raw = Q12_1,
    party_id_raw = `Q14...33`,
    religion_raw = Q85,
    direct_pride_korea = Q69,
    list_pride_count = norm_num(str_trim(Q62)),
    list_pride_treatment_arm = ListKoreanPride_DO,
    direct_nksk_maintain = Q26,
    list_nksk_count = norm_num(str_trim(Q65)),
    list_nksk_treatment_arm = `ListN-SMaintain_DO`,
    national_identity_strength = norm_num(Q86_1)
  )

# North Korean migrant sample --------------------------------------------------
nk_values_raw <- if (file.exists(nk_choice_path)) {
  read_csv(nk_choice_path, show_col_types = FALSE) |> slice(-c(1, 2))
} else {
  read_csv(nk_path, show_col_types = FALSE) |> slice(-c(1, 2))
}

# Reproduce the original qmd-style NK analytic cohort construction (N=301).
nk_cohort_ids <- if (file.exists(nk_choice_path)) {
  nk_translations <- c(
    `강원도` = "Gangwon Province",
    `개성` = "Kaesong",
    `남포` = "Nampo",
    `라진-선봉` = "Rason",
    `량강도` = "Ryanggang Province",
    `자강도` = "Jagang Province",
    `평안남도` = "South Pyongan Province",
    `평안북도` = "North Pyongan Province",
    `평양` = "Pyongyang",
    `함경남도` = "South Hamgyong Province",
    `함경북도` = "North Hamgyong Province",
    `황해남도` = "South Hwanghae Province",
    `황해북도` = "North Hwanghae Province"
  )
  nk_borderlands <- c(
    "North Pyongan Province",
    "Jagang Province",
    "Ryanggang Province",
    "North Hamgyong Province",
    "Rason"
  )

  nk_values_raw |>
    transmute(
      ResponseId = ResponseId,
      Q72 = Q72,
      Q75 = Q75,
      Q53 = Q53,
      Q54 = Q54,
      List1_DO = List1_DO,
      List2_DO = List2_DO,
      yob = norm_num(`Q2...20`),
      party = factor(ifelse(Q15 == "예", 1, 0)),
      female = factor(ifelse(Q6 == "여", 1, 0)),
      yeardefection = norm_num(`Q4...28`),
      timenk = yeardefection - yob,
      timesk = 2023 - norm_num(Q18),
      unemployed = factor(ifelse(Q86 == "예", 1, 0)),
      age = 2023 - yob,
      age_median = ifelse(is.na(age), median(age, na.rm = TRUE), age),
      edunkhigh = ifelse(
        Q7 == "대학교 (3-4년) 졸업" | Q7 == "전문대학교 (2년) 졸업, 기술고급중학교",
        1,
        0
      ),
      natid.strong = ifelse(norm_num(Q123_1) >= 7, 1, 0),
      pob = dplyr::recode(`Q3...21`, !!!nk_translations, .default = `Q3...21`),
      border = if_else(pob %in% nk_borderlands, 1, 0),
      capital = if_else(pob == "Pyongyang", 1, 0),
      edunk = dplyr::recode(
        ifelse(Q7 == "기타", "인민학교 이하", Q7),
        "인민학교 이하" = "Elementary or below",
        "고등중학교 중등반(1-3년) 졸업" = "Lower secondary (1-3 years)",
        "고등중학교 고등반(4-6년) 졸업" = "Upper secondary (4-6 years)",
        "전문대학교 (2년) 졸업, 기술고급중학교" = "2-year technical college, vocational high school",
        "대학교 (3-4년) 졸업" = "University (3-4 years)"
      )
    ) |>
    filter(is.na(pob) | pob != "북조선 외부") |>
    filter(rowSums(across(everything(), ~ is.na(.x))) < 5) |>
    filter(timenk >= 12) |>
    pull(ResponseId)
} else {
  nk_values_raw$ResponseId
}

nk_raw <- nk_values_raw |> filter(ResponseId %in% nk_cohort_ids)

nk <- nk_raw |>
  transmute(
    response_id = ResponseId,
    gender = Q6,
    birth_year = norm_num(`Q2...20`),
    birth_place_raw = `Q3...21`,
    education_nk_raw = Q7,
    father_party_member_raw = Q12,
    mother_party_member_raw = Q14,
    party_member_raw = Q15,
    year_defection = norm_num(`Q4...28`),
    year_arrived_sk = norm_num(Q18),
    reason_defection_raw = Q17,
    residence_sk_raw = Q20,
    education_sk_raw = Q84,
    unemployed_raw = Q86,
    retired_raw = Q87,
    political_orientation_raw = Q91,
    party_preference_raw = Q92,
    marital_status_raw = Q99,
    religion_raw = Q141,
    national_identity_strength = norm_num(Q123_1),
    direct_sk_pride = Q53,
    direct_nk_pride = Q54,
    list_sk_pride_count = norm_num(Q72),
    list_nk_pride_count = norm_num(Q75),
    list_sk_pride_treatment_arm = List1_DO,
    list_nk_pride_treatment_arm = List2_DO
  )

# Write samples ----------------------------------------------------------------
write_csv(tw, file.path(out_samples, "tw_list.csv"), na = "")
write_csv(kr, file.path(out_samples, "kr_list.csv"), na = "")
write_csv(nk, file.path(out_samples, "nk_list.csv"), na = "")

target_counts_si_text <- c(
  tw_list = 2050L,
  kr_list = 1994L,
  nk_list = 301L
)
realized_counts <- c(
  tw_list = nrow(tw),
  kr_list = nrow(kr),
  nk_list = nrow(nk)
)
count_check <- tibble(
  sample = names(realized_counts),
  rows = as.integer(unname(realized_counts)),
  target_si_text = as.integer(unname(target_counts_si_text)),
  matches_si_text = rows == target_si_text
)
message("Sample-size check (SI prose targets):")
print(count_check, n = Inf)

# Dictionaries -----------------------------------------------------------------
tw_used <- c(
  birth_year_roc = "age covariate construction",
  gender = "female indicator",
  ideology_raw = "pol_id covariate",
  education_years = "eduhigh covariate",
  list_pride_treatment_indicator = "List1.n",
  list_pride_taiwan_count = "list outcome",
  direct_pride_taiwan = "direct binary outcome",
  identity_category_raw = "strong/weak subgroup split"
)

kr_used <- c(
  age = "age covariate",
  gender = "female indicator",
  education_raw = "eduhigh covariate",
  ideology_scale_raw = "political_orientation covariate",
  list_pride_count = "list model outcome",
  direct_pride_korea = "direct binary outcome",
  list_pride_treatment_arm = "treatment indicator",
  national_identity_strength = "strong/weak subgroup split"
)

nk_used <- c(
  birth_year = "timenk calculation",
  gender = "female indicator",
  education_nk_raw = "preserved SI-relevant covariate source",
  party_member_raw = "retained for SI robustness variants and provenance",
  year_defection = "timenk calculation",
  year_arrived_sk = "timesk calculation",
  unemployed_raw = "preserved SI-relevant covariate source",
  list_sk_pride_treatment_arm = "treatskpride",
  list_nk_pride_treatment_arm = "treatnkpride",
  list_sk_pride_count = "SK-pride list outcome",
  list_nk_pride_count = "NK-pride list outcome",
  direct_sk_pride = "SK-pride direct outcome",
  direct_nk_pride = "NK-pride direct outcome"
)

tw_desc <- c(
  response_id = "Respondent ID from the raw Taiwan survey export",
  birth_year_roc = "Birth year in ROC (Minguo) calendar",
  ideology_raw = "Self-reported conservative/liberal placement",
  identity_category_raw = "Identity self-categorization (Taiwanese/Chinese/both/neither)",
  education_years = "Years of formal education",
  direct_pride_taiwan = "Direct question on pride in being Taiwanese",
  direct_pride_china = "Direct question on pride in being Chinese",
  direct_support_unification = "Direct question on support for unification",
  list_pride_treatment_indicator = "List experiment treatment indicator/count (List1)",
  list_pride_taiwan_count = "Observed list count for Taiwan-pride list experiment"
)

kr_desc <- c(
  response_id = "Respondent ID from the raw South Korea survey export",
  ideology_scale_raw = "Raw ideology scale response",
  direct_pride_korea = "Direct question on pride in being South Korean",
  list_pride_count = "List count for pride in being South Korean",
  list_pride_treatment_arm = "Raw treatment assignment for the pride list experiment",
  direct_nksk_maintain = "Direct question on maintaining North-South separation",
  list_nksk_count = "List count for North-South maintenance list experiment",
  list_nksk_treatment_arm = "Raw treatment assignment for North-South maintenance list experiment",
  national_identity_strength = "National identity strength scale"
)

nk_desc <- c(
  response_id = "Respondent ID from the raw North Korean migrant survey export",
  birth_year = "Birth year",
  education_nk_raw = "Education level in North Korea",
  party_member_raw = "Whether respondent was a Workers' Party member",
  year_defection = "Year of departure from North Korea",
  year_arrived_sk = "Year of arrival in South Korea",
  unemployed_raw = "Current unemployment status item",
  direct_sk_pride = "Direct question on pride in being South Korean",
  direct_nk_pride = "Direct question on pride in North Korean origin",
  list_sk_pride_count = "List count for pride in being South Korean",
  list_nk_pride_count = "List count for pride in North Korean origin",
  list_sk_pride_treatment_arm = "Raw treatment assignment for SK-pride list",
  list_nk_pride_treatment_arm = "Raw treatment assignment for NK-pride list",
  national_identity_strength = "National identity strength scale"
)

tw_dict <- make_dictionary(tw, tw_desc, tw_used, "Taiwan background/list/direct variable retained for replication.")
kr_dict <- make_dictionary(kr, kr_desc, kr_used, "South Korea background/list/direct variable retained for replication.")
nk_dict <- make_dictionary(nk, nk_desc, nk_used, "North Korean migrant background/list/direct variable retained for replication.")

write_csv(tw_dict, file.path(out_dict, "tw_list_dictionary.csv"), na = "")
write_csv(kr_dict, file.path(out_dict, "kr_list_dictionary.csv"), na = "")
write_csv(nk_dict, file.path(out_dict, "nk_list_dictionary.csv"), na = "")

message("Wrote data/samples/tw_list.csv")
message("Wrote data/samples/kr_list.csv")
message("Wrote data/samples/nk_list.csv")
message("Wrote data/dictionaries/tw_list_dictionary.csv")
message("Wrote data/dictionaries/kr_list_dictionary.csv")
message("Wrote data/dictionaries/nk_list_dictionary.csv")
