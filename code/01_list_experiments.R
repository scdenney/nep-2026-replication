#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(tibble)
  library(list)
  library(mice)
})

root <- normalizePath(".", mustWork = FALSE)

sample_path <- function(filename) {
  structured <- file.path(root, "data", "samples", filename)
  flat <- file.path(root, filename)
  tab_filename <- sub("\\.csv$", ".tab", filename)
  structured_tab <- file.path(root, "data", "samples", tab_filename)
  flat_tab <- file.path(root, tab_filename)
  if (file.exists(structured)) {
    structured
  } else if (file.exists(flat)) {
    flat
  } else if (file.exists(structured_tab)) {
    structured_tab
  } else {
    flat_tab
  }
}

read_sample <- function(path) {
  header <- readLines(path, n = 1, warn = FALSE)
  count_fixed <- function(pattern, x) {
    matches <- gregexpr(pattern, x, fixed = TRUE)[[1]]
    if (identical(matches, -1L)) 0L else length(matches)
  }
  if (count_fixed("\t", header) > count_fixed(",", header)) {
    read_tsv(path, show_col_types = FALSE)
  } else {
    read_csv(path, show_col_types = FALSE)
  }
}

in_tw <- sample_path("tw_list.csv")
in_sk <- sample_path("kr_list.csv")
in_nk <- sample_path("nk_list.csv")

out_dir <- file.path(root, "outputs", "results")
fig_dir <- file.path(root, "outputs", "figures")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

stop_if_missing <- function(path) {
  if (!file.exists(path)) {
    stop("Required replication input is missing: ", path, call. = FALSE)
  }
}
invisible(lapply(c(in_tw, in_sk, in_nk), stop_if_missing))

num <- function(x) suppressWarnings(as.numeric(x))

yes_taiwan <- function(x) {
  x %in% c(1, "1", "同意")
}

prepare_estimates <- function(pred_object, group_label, country_label, figure_label) {
  fit <- as.data.frame(pred_object$fit) |>
    rownames_to_column("Measure")
  fit$se <- pred_object$se.fit
  fit$Group <- group_label
  fit$Country <- country_label
  fit$Figure <- figure_label
  fit$Measure <- gsub("Difference \\(list - direct\\)", "Difference", fit$Measure)
  fit |>
    select(Figure, Country, Group, Measure, fit, se, lwr, upr)
}

predict_list_direct <- function(data, list_formula, direct_formula, treat, J,
                                sensitive.item = 1, seed = NULL) {
  list_fit <- do.call(
    ictreg,
    list(
      formula = list_formula,
      J = J,
      data = as.data.frame(data),
      treat = treat,
      method = "lm"
    )
  )
  direct_fit <- do.call(
    glm,
    list(formula = direct_formula, data = data, family = binomial("logit"))
  )
  if (!is.null(seed)) {
    set.seed(seed)
  }
  # predict.ictreg() simulates coefficient draws when direct.glm is supplied.
  # Fixed seeds keep the published point labels stable across reruns.
  predict(
    list_fit,
    direct.glm = direct_fit,
    se.fit = TRUE,
    avg = TRUE,
    sensitive.item = sensitive.item
  )
}

prepare_taiwan <- function(path) {
  current_minguo_year <- 2024 - 1911

  read_sample(path) |>
    mutate(
      female = case_when(
        gender %in% c(1, "1", "女性", "女") ~ 1,
        gender %in% c(0, "0", 2, "2", "男性", "男") ~ 0,
        TRUE ~ NA_real_
      ),
      age = current_minguo_year - num(birth_year_roc),
      eduhigh = ifelse(num(education_years) >= 14, 1, 0),
      party_num = num(party_id_raw),
      pol.id = case_when(
        party_num %in% c(2, 5, 6) |
          party_id_raw %in% c("民進黨", "時代力量", "台灣基進黨", "台灣基進") ~ "Left",
        party_num %in% c(1, 4, 7, 8) |
          party_id_raw %in% c("國民黨", "新黨", "親民黨", "台聯", "台灣團結聯盟") ~ "Right",
        TRUE ~ "Center"
      ),
      pol.id = factor(pol.id, levels = c("Center", "Left", "Right")),
      twidstrength = num(taiwanese_identity_strength),
      twidstrength.bi = ifelse(twidstrength == 10, 1, 0),
      chineseidstrength = num(chinese_identity_strength),
      chineseidstrength.bi = ifelse(chineseidstrength >= 6, 1, 0),
      chinese.nation.idstrength = num(chinese_nation_identity_strength),
      chinese.nation.idstrength.bi = ifelse(chinese.nation.idstrength == 10, 1, 0),
      twid = ifelse(twidstrength.bi == 1 & chineseidstrength.bi == 0, 1, 0),
      chid = ifelse(twidstrength.bi == 0 & chineseidstrength.bi == 1, 1, 0),
      twch.both.bi = ifelse(twidstrength.bi == 1 & chineseidstrength.bi == 1, 1, 0),
      List1.n = num(list_pride_treatment_indicator),
      List2.n = num(list_independence_treatment_indicator),
      pride.tw.y = num(list_pride_taiwan_count),
      pride.ch.y = num(list_pride_china_count),
      tw.proud.dq = ifelse(yes_taiwan(direct_pride_taiwan), 1, 0),
      ch.proud.dq = ifelse(yes_taiwan(direct_pride_china), 1, 0),
      ind.support.dq = ifelse(yes_taiwan(direct_support_independence), 1, 0),
      father_num = num(father_origin_raw),
      father_origin = case_when(
        father_num %in% c(1, 2) | father_origin_raw %in% c("台灣閩南人", "台灣客家人") ~ "Benshengren",
        father_num %in% c(4, 5) | father_origin_raw %in% c("大陸各省市人", "台灣的外省人") ~ "Waishengren",
        father_num == 3 | father_origin_raw == "台灣原住民" ~ "Indigenous",
        father_num %in% c(6, 7) | father_origin_raw %in% c("東南亞（國家）的人", "其他外國人") ~ "NewResident_Foreign",
        father_num == 8 | father_origin_raw == "其他" ~ "Other",
        TRUE ~ NA_character_
      ),
      father_origin = factor(
        father_origin,
        levels = c("Benshengren", "Waishengren", "Indigenous", "NewResident_Foreign", "Other")
      )
    ) |>
    select(
      List1.n, List2.n, pride.tw.y, pride.ch.y,
      tw.proud.dq, ch.proud.dq, ind.support.dq,
      age, eduhigh, female, pol.id,
      twidstrength.bi, chineseidstrength.bi, twch.both.bi,
      chinese.nation.idstrength.bi, twid, chid, father_origin
    ) |>
    mutate(age_median = ifelse(age >= median(age, na.rm = TRUE), 1, 0)) |>
    as.data.frame()
}

prepare_south_korea <- function(path) {
  read_sample(path) |>
    mutate(
      female = ifelse(gender == "여성", 1, 0),
      eduhigh = ifelse(
        education_raw %in% c("대학교", "대학원 이상", "전문 대학교(기술 학교 포함)"),
        1,
        0
      ),
      polid.num = num(gsub(".*?(\\d+).*", "\\1", ideology_scale_raw)),
      political_orientation = case_when(
        polid.num >= 1 & polid.num <= 4 ~ "Progressive",
        polid.num >= 7 & polid.num <= 10 ~ "Conservative",
        polid.num > 4 & polid.num < 7 ~ "Centrist",
        TRUE ~ NA_character_
      ),
      pride = ifelse(direct_pride_korea %in% c("매우 자랑스럽다", "어느 정도 자랑스럽다"), 1, 0),
      list_pride = num(list_pride_count),
      pride.treat = ifelse(
        list_pride_treatment_arm == "Q60|Q62",
        0,
        ifelse(list_pride_treatment_arm == "Q61|Q62", 1, NA)
      ),
      list_nksk = num(list_nksk_count),
      nksk.treat = ifelse(
        list_nksk_treatment_arm == "Q63|Q65",
        0,
        ifelse(list_nksk_treatment_arm == "Q64|Q65", 1, NA)
      ),
      natidnum = num(national_identity_strength),
      natid.strong = ifelse(natidnum >= 9, 1, 0),
      natid.strong_2 = ifelse(natidnum == 10, 1, 0)
    ) |>
    filter(list_pride %% 1 == 0) |>
    filter(list_nksk %% 1 == 0) |>
    filter(!is.na(age), is.na(region_raw) | region_raw != "해외") |>
    select(
      response_id, random_text_flag, female, eduhigh, age,
      polid.num, political_orientation, pride, pride.treat, list_pride,
      list_nksk, nksk.treat, natid.strong, natidnum, natid.strong_2
    ) |>
    as.data.frame()
}

prepare_north_korean_migrants <- function(path) {
  nk <- read_sample(path)

  nk_subset <- nk |>
    mutate(
      id = row_number(),
      yob = num(birth_year),
      age = 2023 - yob,
      age_median = ifelse(is.na(age), median(age, na.rm = TRUE), age),
      party = factor(ifelse(party_member_raw == "예", 1, 0)),
      female = factor(ifelse(gender == "여", 1, 0)),
      yeardefection = num(year_defection),
      timenk = yeardefection - yob,
      timesk = 2023 - num(year_arrived_sk),
      unemployed = factor(ifelse(unemployed_raw == "예", 1, 0)),
      edunkhigh = ifelse(
        education_nk_raw %in% c("대학교 (3-4년) 졸업", "전문대학교 (2년) 졸업, 기술고급중학교"),
        1,
        0
      ),
      natid.strong = ifelse(num(national_identity_strength) >= 7, 1, 0),
      pob = birth_place_english,
      border = num(border_region),
      capital = num(capital_region),
      edunk = factor(
        education_nk_english,
        levels = c(
          "Elementary or below",
          "Lower secondary (1-3 years)",
          "Upper secondary (4-6 years)",
          "2-year technical college, vocational high school",
          "University (3-4 years)"
        )
      )
    ) |>
    select(
      id, list_sk_pride_count, list_nk_pride_count, direct_sk_pride, direct_nk_pride,
      list_sk_pride_treatment_arm, list_nk_pride_treatment_arm,
      yob, party, female, yeardefection, timenk, timesk, unemployed,
      age, age_median, edunkhigh, natid.strong, pob, border, capital, edunk
    ) |>
    mutate(
      list_sk_pride_count = as.character(list_sk_pride_count),
      list_nk_pride_count = as.character(list_nk_pride_count)
    ) |>
    filter(is.na(pob) | pob != "북조선 외부") |>
    (\(x) x[rowSums(is.na(x)) < 5, , drop = FALSE])() |>
    filter(timenk >= 12)

  imputed_data <- suppressWarnings(
    mice(nk_subset, m = 5, maxit = 50, seed = 123, printFlag = FALSE)
  )

  complete(imputed_data, action = 1) |>
    mutate(
      treatskpride = if_else(list_sk_pride_treatment_arm == "Q71|Q72", 1L, 0L),
      treatnkpride = if_else(list_nk_pride_treatment_arm == "Q74|Q75", 0L, 1L),
      skpride_list = num(list_sk_pride_count),
      nkpride_list = num(list_nk_pride_count),
      skpride_direct = case_when(
        direct_sk_pride %in% c("전혀 자랑스럽지 않다", "별로 자랑스럽지 않다") ~ 0,
        TRUE ~ 1
      ),
      nkpride_direct = case_when(
        direct_nk_pride %in% c("전혀 자랑스럽지 않다", "별로 자랑스럽지 않다") ~ 0,
        TRUE ~ 1
      )
    ) |>
    as.data.frame()
}

label_pct <- function(x) paste0(round(x * 100, 1), "%")

plot_country_overlay <- function(data, file) {
  data$Country <- factor(data$Country, levels = c("Taiwan", "South Korea"))

  p <- ggplot(data, aes(x = Measure, y = fit, group = Country)) +
    geom_hline(yintercept = 0, color = "grey60", linetype = "dotted", linewidth = 0.8) +
    geom_errorbar(
      aes(ymin = lwr, ymax = upr, color = Country),
      position = position_dodge(width = 0.3),
      width = 0,
      linewidth = 1
    ) +
    geom_errorbar(
      aes(ymin = fit - 1.645 * se, ymax = fit + 1.645 * se, color = Country),
      position = position_dodge(width = 0.3),
      width = 0,
      linewidth = 2
    ) +
    geom_point(
      position = position_dodge(width = 0.3),
      size = 3,
      shape = 21,
      stroke = 1,
      fill = "white",
      aes(color = Country)
    ) +
    geom_text(
      data = filter(data, Country == "Taiwan"),
      aes(label = label_pct(fit)),
      position = position_dodge(0.3),
      hjust = 1.4,
      size = 5,
      color = "black"
    ) +
    geom_text(
      data = filter(data, Country == "South Korea"),
      aes(label = label_pct(fit)),
      position = position_dodge(0.3),
      hjust = -0.45,
      size = 5,
      color = "grey40"
    ) +
    facet_wrap(~ Group, scales = "free_x") +
    scale_color_manual(values = c("Taiwan" = "black", "South Korea" = "grey60")) +
    scale_x_discrete(labels = c("Direct", "List", "Difference")) +
    scale_y_continuous(labels = function(x) paste0(x * 100, "%")) +
    coord_cartesian(ylim = c(-0.5, 1)) +
    theme_minimal(base_size = 16) +
    theme(
      strip.text = element_text(face = "bold"),
      axis.title.y = element_text(size = 14, angle = 90, vjust = 1.2, hjust = 0.5),
      axis.text = element_text(size = 12),
      panel.grid.major.y = element_line(linewidth = 0.3, linetype = "dotted"),
      panel.spacing = unit(0.5, "lines"),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
      legend.position = "bottom",
      legend.title = element_text(size = 13),
      legend.text = element_text(size = 12)
    ) +
    labs(x = NULL, y = "Estimated Proportions", color = "Sample")

  ggsave(file, p, device = "pdf", width = 16, height = 8, dpi = 300)
  invisible(p)
}

plot_single_sample <- function(data, file, y_limits, width, height) {
  p <- ggplot(data, aes(x = Measure, y = fit)) +
    geom_hline(yintercept = 0, color = "grey60", linetype = "dotted", linewidth = 0.8) +
    geom_errorbar(aes(ymin = lwr, ymax = upr), width = 0, linewidth = 1, color = "black") +
    geom_errorbar(
      aes(ymin = fit - 1.645 * se, ymax = fit + 1.645 * se),
      width = 0,
      linewidth = 2,
      color = "black"
    ) +
    geom_point(size = 2, shape = 21, fill = "white", color = "black", stroke = 1) +
    geom_text(aes(label = label_pct(fit)), hjust = -0.3, size = 4) +
    facet_wrap(~ Group, scales = "free_x") +
    scale_x_discrete(labels = c("Direct", "List", "Difference")) +
    scale_y_continuous(labels = function(x) paste0(x * 100, "%")) +
    coord_cartesian(ylim = y_limits) +
    labs(x = NULL, y = "Estimated Proportions") +
    theme_minimal() +
    theme(
      strip.text = element_text(face = "bold"),
      axis.title.y = element_text(size = 12, angle = 90, vjust = 1.2, hjust = 0.5),
      axis.text.y = element_text(size = 10),
      panel.grid.major.y = element_line(linewidth = 0.3, linetype = "dotted"),
      panel.spacing = unit(0.5, "lines"),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
      legend.position = "none"
    )

  ggsave(file, p, device = "pdf", width = width, height = height, units = "in", dpi = 300)
  invisible(p)
}

tw <- prepare_taiwan(in_tw)
sk <- prepare_south_korea(in_sk)
nk <- prepare_north_korean_migrants(in_nk)

# Figure 2: Taiwan pride by subjective identity subgroup.
pred_tw_all <- predict_list_direct(
  tw,
  pride.tw.y ~ age + female + eduhigh + pol.id,
  tw.proud.dq ~ age + female + eduhigh + pol.id,
  treat = "List1.n",
  J = 3,
  seed = 1
)
pred_tw_twid <- predict_list_direct(
  subset(tw, twid == 1),
  pride.tw.y ~ age + female + eduhigh + pol.id,
  tw.proud.dq ~ age + female + eduhigh + pol.id,
  treat = "List1.n",
  J = 3,
  seed = 605
)
pred_tw_chid <- predict_list_direct(
  subset(tw, chineseidstrength.bi == 1),
  pride.tw.y ~ age + female + eduhigh + pol.id,
  tw.proud.dq ~ age + female + eduhigh + pol.id,
  treat = "List1.n",
  J = 3,
  seed = 9
)

figure2 <- bind_rows(
  prepare_estimates(pred_tw_all, "All respondents", "Taiwan", "Figure 2"),
  prepare_estimates(pred_tw_twid, "Taiwanese-only identifiers", "Taiwan", "Figure 2"),
  prepare_estimates(pred_tw_chid, "Taiwanese-Chinese identifiers", "Taiwan", "Figure 2")
) |>
  mutate(
    Measure = factor(Measure, levels = c("Direct", "List", "Difference")),
    Group = factor(
      Group,
      levels = c("All respondents", "Taiwanese-only identifiers", "Taiwanese-Chinese identifiers")
    )
  )

# Figure 1: Taiwan and South Korea by national identity strength.
pred_tw_strong <- predict_list_direct(
  subset(tw, twidstrength.bi == 1),
  pride.tw.y ~ age + female + eduhigh + pol.id,
  tw.proud.dq ~ age + female + eduhigh + pol.id,
  treat = "List1.n",
  J = 3,
  seed = 53
)
pred_tw_weak <- predict_list_direct(
  subset(tw, twidstrength.bi == 0),
  pride.tw.y ~ age + female + eduhigh + pol.id,
  tw.proud.dq ~ age + female + eduhigh + pol.id,
  treat = "List1.n",
  J = 3,
  seed = 3
)
pred_sk_all <- predict_list_direct(
  sk,
  list_pride ~ age + eduhigh + female + political_orientation,
  pride ~ age + eduhigh + female + political_orientation,
  treat = "pride.treat",
  J = 4,
  seed = 1
)

# Preserve the published Quarto specification: the list model uses >= 9,
# while the direct model uses the stricter == 10 split.
sk_strong_list <- ictreg(
  list_pride ~ age + eduhigh + female + political_orientation,
  J = 4,
  data = subset(sk, natid.strong == 1),
  treat = "pride.treat",
  method = "lm"
)
sk_strong_direct <- glm(
  pride ~ age + eduhigh + female + political_orientation,
  data = subset(sk, natid.strong_2 == 1),
  family = binomial("logit")
)
set.seed(1)
pred_sk_strong <- predict(
  sk_strong_list,
  direct.glm = sk_strong_direct,
  se.fit = TRUE,
  avg = TRUE,
  sensitive.item = 1
)
pred_sk_weak <- predict_list_direct(
  subset(sk, natid.strong == 0),
  list_pride ~ age + eduhigh + female + political_orientation,
  pride ~ age + eduhigh + female + political_orientation,
  treat = "pride.treat",
  J = 4,
  seed = 2
)

figure1 <- bind_rows(
  prepare_estimates(pred_sk_all, "All Respondents", "South Korea", "Figure 1"),
  prepare_estimates(pred_sk_strong, "Strong National Identity", "South Korea", "Figure 1"),
  prepare_estimates(pred_sk_weak, "Weak National Identity", "South Korea", "Figure 1"),
  prepare_estimates(pred_tw_all, "All Respondents", "Taiwan", "Figure 1"),
  prepare_estimates(pred_tw_strong, "Strong National Identity", "Taiwan", "Figure 1"),
  prepare_estimates(pred_tw_weak, "Weak National Identity", "Taiwan", "Figure 1")
) |>
  mutate(
    Measure = factor(Measure, levels = c("Direct", "List", "Difference")),
    Group = factor(
      Group,
      levels = c("All Respondents", "Strong National Identity", "Weak National Identity")
    ),
    Country = factor(Country, levels = c("Taiwan", "South Korea"))
  )

# Figure 3: Taiwan pride by paternal-origin group.
pred_tw_ben <- predict_list_direct(
  subset(tw, father_origin == "Benshengren"),
  pride.tw.y ~ age + female + eduhigh + pol.id,
  tw.proud.dq ~ age + female + eduhigh + pol.id,
  treat = "List1.n",
  J = 3,
  seed = 5
)
pred_tw_wai <- predict_list_direct(
  subset(tw, father_origin == "Waishengren"),
  pride.tw.y ~ age + female + eduhigh + pol.id,
  tw.proud.dq ~ age + female + eduhigh + pol.id,
  treat = "List1.n",
  J = 3,
  seed = 6
)
figure3 <- bind_rows(
  prepare_estimates(pred_tw_ben, "Benshengren", "Taiwan", "Figure 3"),
  prepare_estimates(pred_tw_wai, "Waishengren", "Taiwan", "Figure 3")
) |>
  mutate(
    Measure = factor(Measure, levels = c("Direct", "List", "Difference")),
    Group = factor(Group, levels = c("Benshengren", "Waishengren"))
  )

# Figure 4: Chinese pride in Taiwan.
tw$treat.ch <- ifelse(tw$List1.n > 0, 1, 0)
set.seed(2)
pred_ch_all <- predict(
  ictreg(
    pride.ch.y ~ age + female + eduhigh + pol.id,
    J = 3,
    data = subset(tw, List1.n != 1),
    treat = "treat.ch",
    method = "lm"
  ),
  direct.glm = glm(ch.proud.dq ~ age + female + eduhigh + pol.id, data = tw, family = binomial("logit")),
  se.fit = TRUE,
  avg = TRUE,
  sensitive.item = 1
)
set.seed(6)
pred_ch_twid <- predict(
  ictreg(
    pride.ch.y ~ age + female + eduhigh + pol.id,
    J = 3,
    data = subset(tw, twid == 1 & List1.n != 1),
    treat = "treat.ch",
    method = "lm"
  ),
  direct.glm = glm(ch.proud.dq ~ age + female + eduhigh + pol.id, data = subset(tw, twid == 1), family = binomial("logit")),
  se.fit = TRUE,
  avg = TRUE,
  sensitive.item = 1
)
set.seed(40)
pred_ch_chid <- predict(
  ictreg(
    pride.ch.y ~ age + female + eduhigh + pol.id,
    J = 3,
    data = subset(tw, chineseidstrength.bi == 1),
    treat = "treat.ch",
    method = "lm"
  ),
  direct.glm = glm(ch.proud.dq ~ age + female + eduhigh + pol.id, data = subset(tw, chineseidstrength.bi == 1), family = binomial("logit")),
  se.fit = TRUE,
  avg = TRUE,
  sensitive.item = 1
)
figure4 <- bind_rows(
  prepare_estimates(pred_ch_all, "All respondents", "Taiwan", "Figure 4"),
  prepare_estimates(pred_ch_twid, "Taiwanese-only identifiers", "Taiwan", "Figure 4"),
  prepare_estimates(pred_ch_chid, "Taiwanese-Chinese identifiers", "Taiwan", "Figure 4")
) |>
  mutate(
    Measure = factor(Measure, levels = c("Direct", "List", "Difference")),
    Group = factor(
      Group,
      levels = c("All respondents", "Taiwanese-only identifiers", "Taiwanese-Chinese identifiers")
    )
  )

# Figure 5: native South Koreans and North Korean migrants.
pred_nk_sk <- predict_list_direct(
  nk,
  skpride_list ~ female + timesk + timenk,
  skpride_direct ~ female + timesk + timenk,
  treat = "treatskpride",
  J = 3,
  seed = 43
)
pred_nk_nk <- predict_list_direct(
  nk,
  nkpride_list ~ female + timesk + timenk,
  nkpride_direct ~ female + timesk + timenk,
  treat = "treatnkpride",
  J = 3,
  seed = 3
)
figure5 <- bind_rows(
  prepare_estimates(
    pred_sk_all,
    "Pride in being South Korean\nNative South Koreans",
    "South Korea",
    "Figure 5"
  ),
  prepare_estimates(
    pred_nk_sk,
    "Pride in being South Korean\nNorth Korean migrants",
    "North Korean migrants",
    "Figure 5"
  ),
  prepare_estimates(
    pred_nk_nk,
    "Pride in being from North Korea\nNorth Korean migrants",
    "North Korean migrants",
    "Figure 5"
  )
) |>
  mutate(
    Measure = factor(Measure, levels = c("Direct", "List", "Difference")),
    Group = factor(
      Group,
      levels = c(
        "Pride in being South Korean\nNative South Koreans",
        "Pride in being South Korean\nNorth Korean migrants",
        "Pride in being from North Korea\nNorth Korean migrants"
      )
    )
  )

all_estimates <- bind_rows(figure1, figure2, figure3, figure4, figure5)
write_csv(all_estimates, file.path(out_dir, "list_experiment_estimates.csv"))

plot_country_overlay(figure1, file.path(fig_dir, "Figure 1.pdf"))
plot_single_sample(figure2, file.path(fig_dir, "Figure 2.pdf"), c(-0.6, 1), 14, 8)
plot_single_sample(figure3, file.path(fig_dir, "Figure 3.pdf"), c(-0.6, 1), 12, 6)
plot_single_sample(figure4, file.path(fig_dir, "Figure 4.pdf"), c(-0.3, 1), 14, 7)
plot_single_sample(figure5, file.path(fig_dir, "Figure 5.pdf"), c(-1, 1), 14, 7)

message("Saved: outputs/results/list_experiment_estimates.csv")
message("Saved: outputs/figures/Figure 1.pdf")
message("Saved: outputs/figures/Figure 2.pdf")
message("Saved: outputs/figures/Figure 3.pdf")
message("Saved: outputs/figures/Figure 4.pdf")
message("Saved: outputs/figures/Figure 5.pdf")
