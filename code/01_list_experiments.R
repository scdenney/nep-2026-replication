#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(stringr)
  library(tibble)
  library(list)
})

`%||%` <- function(x, y) if (is.null(x)) y else x
root <- normalizePath(".", mustWork = FALSE)

in_tw <- file.path(root, "data/samples/tw_list.csv")
in_kr <- file.path(root, "data/samples/kr_list.csv")
in_nk <- file.path(root, "data/samples/nk_list.csv")
out_dir <- file.path(root, "outputs/results")
fig_dir <- file.path(root, "outputs/figures")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

prepare_estimates <- function(pred_object, group_label, country_label) {
  fit <- as.data.frame(pred_object$fit) |> rownames_to_column("Measure")
  fit$se <- pred_object$se.fit
  fit$Group <- group_label
  fit$Country <- country_label
  fit$Measure <- gsub("Difference \\(list - direct\\)", "Difference", fit$Measure)
  fit
}

plot_list_summary <- function(df, title = NULL, y_limits = c(-0.6, 1.0)) {
  ggplot(df, aes(x = Measure, y = fit, color = Country)) +
    geom_hline(yintercept = 0, color = "grey60", linetype = "dotted", linewidth = 0.8) +
    geom_errorbar(aes(ymin = lwr, ymax = upr), width = 0, linewidth = 1, position = position_dodge(width = 0.2)) +
    geom_errorbar(aes(ymin = fit - 1.645 * se, ymax = fit + 1.645 * se), width = 0, linewidth = 2, position = position_dodge(width = 0.2)) +
    geom_point(size = 2.2, shape = 21, fill = "white", stroke = 1, position = position_dodge(width = 0.2)) +
    facet_wrap(~ Group, scales = "free_x") +
    scale_x_discrete(limits = c("Direct", "List", "Difference")) +
    scale_y_continuous(labels = function(x) paste0(round(x * 100), "%")) +
    coord_cartesian(ylim = y_limits) +
    labs(x = NULL, y = "Estimated proportions", title = title, color = NULL) +
    theme_minimal(base_size = 12) +
    theme(
      strip.text = element_text(face = "bold"),
      legend.position = "bottom",
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5)
    )
}

# Taiwan ----------------------------------------------------------------------
tw_raw <- read_csv(in_tw, show_col_types = FALSE)

tw <- tw_raw |>
  transmute(
    age = 2024 - (birth_year_roc + 1911),
    female = if_else(gender == "女性", 1, 0, missing = NA_real_),
    eduhigh = if_else(education_years >= 16, 1, 0, missing = NA_real_),
    pol_id = case_when(
      ideology_raw %in% c("保守主義", "接近保守主義") ~ "Conservative",
      ideology_raw %in% c("自由主義", "接近自由主義") ~ "Progressive",
      ideology_raw == "中立" ~ "Centrist",
      TRUE ~ NA_character_
    ),
    List1.n = list_pride_treatment_indicator,
    pride.tw.y = list_pride_taiwan_count,
    tw.proud.dq = if_else(direct_pride_taiwan == "同意", 1, if_else(direct_pride_taiwan %in% c("不同意", "不知道"), 0, NA_real_)),
    identity_categorical = case_when(
      identity_category_raw == "台灣人" ~ "Taiwanese-only identifiers",
      identity_category_raw == "兩者都是" ~ "Taiwanese-Chinese identifiers",
      TRUE ~ "All respondents"
    )
  ) |>
  filter(!is.na(age), !is.na(female), !is.na(eduhigh), !is.na(pol_id), !is.na(List1.n), !is.na(pride.tw.y), !is.na(tw.proud.dq))

fit_tw <- ictreg(pride.tw.y ~ age + female + eduhigh + pol_id, J = 3, data = as.data.frame(tw), treat = "List1.n", method = "lm")
fit_tw_direct <- glm(tw.proud.dq ~ age + female + eduhigh + pol_id, data = tw, family = binomial("logit"))
pred_tw <- predict(fit_tw, direct.glm = fit_tw_direct, se.fit = TRUE, avg = TRUE, sensitive.item = 1)

fit_tw_strong <- tw |> filter(identity_categorical == "Taiwanese-only identifiers")
fit_tw_weak <- tw |> filter(identity_categorical == "Taiwanese-Chinese identifiers")

pred_tw_strong <- predict(
  ictreg(pride.tw.y ~ age + female + eduhigh + pol_id, J = 3, data = as.data.frame(fit_tw_strong), treat = "List1.n", method = "lm"),
  direct.glm = glm(tw.proud.dq ~ age + female + eduhigh + pol_id, data = fit_tw_strong, family = binomial("logit")),
  se.fit = TRUE, avg = TRUE, sensitive.item = 1
)

pred_tw_weak <- predict(
  ictreg(pride.tw.y ~ age + female + eduhigh + pol_id, J = 3, data = as.data.frame(fit_tw_weak), treat = "List1.n", method = "lm"),
  direct.glm = glm(tw.proud.dq ~ age + female + eduhigh + pol_id, data = fit_tw_weak, family = binomial("logit")),
  se.fit = TRUE, avg = TRUE, sensitive.item = 1
)

tw_est <- bind_rows(
  prepare_estimates(pred_tw, "All respondents", "Taiwan"),
  prepare_estimates(pred_tw_strong, "Strong National Identity", "Taiwan"),
  prepare_estimates(pred_tw_weak, "Weak National Identity", "Taiwan")
)

# South Korea -----------------------------------------------------------------
kr_raw <- read_csv(in_kr, show_col_types = FALSE)

parse_ideology_score <- function(x) suppressWarnings(as.numeric(str_extract(x, "^[0-9]+")))

kr <- kr_raw |>
  transmute(
    age = age,
    female = if_else(gender == "여성", 1, 0, missing = NA_real_),
    eduhigh = if_else(education_raw %in% c("전문 대학교(기술 학교 포함)", "대학교", "대학원 이상"), 1, 0, missing = NA_real_),
    political_orientation = parse_ideology_score(ideology_scale_raw),
    list_pride = list_pride_count,
    pride = if_else(direct_pride_korea %in% c("매우 자랑스럽다", "어느 정도 자랑스럽다"), 1,
                    if_else(direct_pride_korea %in% c("별로 자랑스럽지 않다", "전혀 자랑스럽지 않다"), 0, NA_real_)),
    pride.treat = if_else(list_pride_treatment_arm == "Q60|Q62", 0, if_else(list_pride_treatment_arm == "Q61|Q62", 1, NA_real_)),
    natid_strength = national_identity_strength,
    natid.strong = if_else(natid_strength >= 7, 1, 0, missing = NA_real_)
  ) |>
  filter(!is.na(age), !is.na(female), !is.na(eduhigh), !is.na(political_orientation),
         !is.na(list_pride), !is.na(pride), !is.na(pride.treat), !is.na(natid.strong)) |>
  filter(list_pride %% 1 == 0)

fit_kr <- ictreg(list_pride ~ age + eduhigh + female + political_orientation, J = 4, data = as.data.frame(kr), treat = "pride.treat", method = "lm")
fit_kr_direct <- glm(pride ~ age + eduhigh + female + political_orientation, data = kr, family = binomial("logit"))
pred_kr <- predict(fit_kr, direct.glm = fit_kr_direct, se.fit = TRUE, avg = TRUE)

kr_strong <- kr |> filter(natid.strong == 1)
kr_weak <- kr |> filter(natid.strong == 0)

pred_kr_strong <- predict(
  ictreg(list_pride ~ age + eduhigh + female + political_orientation, J = 4, data = as.data.frame(kr_strong), treat = "pride.treat", method = "lm"),
  direct.glm = glm(pride ~ age + eduhigh + female + political_orientation, data = kr_strong, family = binomial("logit")),
  se.fit = TRUE, avg = TRUE, sensitive.item = 1
)

pred_kr_weak <- predict(
  ictreg(list_pride ~ age + eduhigh + female + political_orientation, J = 4, data = as.data.frame(kr_weak), treat = "pride.treat", method = "lm"),
  direct.glm = glm(pride ~ age + eduhigh + female + political_orientation, data = kr_weak, family = binomial("logit")),
  se.fit = TRUE, avg = TRUE, sensitive.item = 1
)

kr_est <- bind_rows(
  prepare_estimates(pred_kr, "All respondents", "South Korea"),
  prepare_estimates(pred_kr_strong, "Strong National Identity", "South Korea"),
  prepare_estimates(pred_kr_weak, "Weak National Identity", "South Korea")
)

combined <- bind_rows(tw_est, kr_est) |>
  mutate(
    Measure = factor(Measure, levels = c("Direct", "List", "Difference")),
    Group = factor(Group, levels = c("All respondents", "Strong National Identity", "Weak National Identity")),
    Country = factor(Country, levels = c("Taiwan", "South Korea"))
  )

write_csv(combined, file.path(out_dir, "list_experiment_estimates.csv"))

p <- plot_list_summary(combined, title = "List vs direct estimates by country and identity group", y_limits = c(-0.8, 1.0))
ggsave(file.path(fig_dir, "SI_List_Experiment_Main.pdf"), p, width = 14, height = 8, dpi = 300)

# North Korean migrant block ---------------------------------------------------
if (file.exists(in_nk)) {
  nk_raw <- read_csv(in_nk, show_col_types = FALSE)

  nk <- nk_raw |>
    transmute(
      yob = birth_year,
      female = if_else(gender == "여", 1, 0, missing = NA_real_),
      party = if_else(party_member_raw == "예", 1, if_else(is.na(party_member_raw), NA_real_, 0)),
      yeardefection = year_defection,
      yeararrived = year_arrived_sk,
      timenk = yeardefection - yob,
      timesk = 2023 - yeararrived,
      treatskpride = if_else(list_sk_pride_treatment_arm == "Q71|Q72", 1, if_else(list_sk_pride_treatment_arm == "Q70|Q72", 0, NA_real_)),
      treatnkpride = if_else(list_nk_pride_treatment_arm == "Q74|Q75", 0, if_else(list_nk_pride_treatment_arm == "Q73|Q75", 1, NA_real_)),
      skpride_list = list_sk_pride_count,
      nkpride_list = list_nk_pride_count,
      skpride_direct = if_else(direct_sk_pride %in% c("전혀 자랑스럽지 않다", "별로 자랑스럽지 않다"), 0,
                               if_else(direct_sk_pride %in% c("어느 정도 자랑스럽다", "매우 자랑스럽다"), 1, NA_real_)),
      nkpride_direct = if_else(direct_nk_pride %in% c("전혀 자랑스럽지 않다", "별로 자랑스럽지 않다"), 0,
                               if_else(direct_nk_pride %in% c("어느 정도 자랑스럽다", "매우 자랑스럽다"), 1, NA_real_))
    ) |>
    filter(
      !is.na(female), !is.na(timesk), !is.na(timenk),
      !is.na(treatskpride), !is.na(treatnkpride),
      !is.na(skpride_list), !is.na(nkpride_list),
      !is.na(skpride_direct), !is.na(nkpride_direct),
      timenk >= 12
    ) |>
    filter(skpride_list %% 1 == 0, nkpride_list %% 1 == 0)

  pred_nk_sk <- predict(
    ictreg(skpride_list ~ female + timesk + timenk, data = as.data.frame(nk), treat = "treatskpride", J = 3, method = "lm"),
    direct.glm = glm(skpride_direct ~ female + timesk + timenk, data = nk, family = binomial("logit")),
    se.fit = TRUE, avg = TRUE
  )

  pred_nk_nk <- predict(
    ictreg(nkpride_list ~ female + timesk + timenk, data = as.data.frame(nk), treat = "treatnkpride", J = 3, method = "lm"),
    direct.glm = glm(nkpride_direct ~ female + timesk + timenk, data = nk, family = binomial("logit")),
    se.fit = TRUE, avg = TRUE
  )

  korea_nk <- bind_rows(
    prepare_estimates(pred_kr, "Pride in being South Korean\nNative South Koreans", "South Korea"),
    prepare_estimates(pred_nk_sk, "Pride in being South Korean\nNorth Korean migrants", "North Korean migrants"),
    prepare_estimates(pred_nk_nk, "Pride in being from North Korea\nNorth Korean migrants", "North Korean migrants")
  ) |>
    mutate(Measure = factor(Measure, levels = c("Direct", "List", "Difference")))

  write_csv(korea_nk, file.path(out_dir, "list_experiment_korea_nk_estimates.csv"))
  p_nk <- plot_list_summary(korea_nk, title = "Korea and North Korean migrant list experiments", y_limits = c(-1.0, 1.0))
  ggsave(file.path(fig_dir, "Figure_5_generated.pdf"), p_nk, width = 14, height = 7, dpi = 300)
  message("Saved: outputs/results/list_experiment_korea_nk_estimates.csv")
  message("Saved: outputs/figures/Figure_5_generated.pdf")
} else {
  warning("North Korean raw file not found; skipped NK migrant block.")
}

message("Saved: outputs/results/list_experiment_estimates.csv")
message("Saved: outputs/figures/SI_List_Experiment_Main.pdf")
