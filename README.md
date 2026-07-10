<div align="center">

<img alt="Identity Conformity in Taiwan and South Korea" src="https://img.shields.io/badge/%F0%9F%87%B9%F0%9F%87%BC_%F0%9F%87%B0%F0%9F%87%B7-Identity_Conformity_in_Divided_Societies-8e44ad?style=for-the-badge&labelColor=1a1a2e">

**Why Citizens in Divided Societies Are Pressured to Overstate National Pride**

*Denney, Steinhardt, & Bhowmick (2026) &mdash; Nationalism and Ethnic Politics (Routledge)*

[![DOI: Paper](https://img.shields.io/badge/DOI-10.1080%2F13537113.2026.2616954-blue?style=flat-square)](https://doi.org/10.1080/13537113.2026.2616954) [![Open Science](https://img.shields.io/badge/Open_Science-Replication_Materials-brightgreen?style=flat-square&logo=opensourceinitiative&logoColor=white)](https://github.com/scdenney/nep-2026-replication) [![R](https://img.shields.io/badge/R-%E2%89%A5_4.0-276DC3?style=flat-square&logo=r&logoColor=white)](#requirements)

</div>

---

## Overview

This package replicates the **list experiments on national pride** from:

> Denney, Steven, H. Christoph Steinhardt, and Lisa Bhowmick. 2026. "Identity Conformity in Taiwan and South Korea: Why Citizens in Divided Societies Are Pressured to Overstate National Pride." *Nationalism and Ethnic Politics*. DOI: [10.1080/13537113.2026.2616954](https://doi.org/10.1080/13537113.2026.2616954)

The study uses list experiments (item-count technique) to measure social desirability bias in expressions of national pride across three populations: Taiwanese citizens, native South Koreans, and North Korean migrants in South Korea. By comparing direct survey responses with indirect list-experiment estimates, the analysis quantifies identity conformity pressures in divided societies with contested national identities.

## Repository Structure

```
.
├── README.md
├── run_replication.R        # One-click: installs packages + runs analysis
├── Makefile                 # make → runs analysis from command line
├── code/
│   ├── 01_list_experiments.R   # Main analysis (list-experiment models + figures)
│   ├── 00_build_samples.R      # Data provenance (requires raw Qualtrics; not needed to replicate)
│   ├── 00_verify_inputs.R      # Input file verification
│   ├── 00_data_audit.R         # Data quality checks
│   ├── requirements.R          # Package installation
│   └── run_all.R               # Pipeline orchestration
├── data/
│   ├── samples/
│   │   ├── tw_list.csv
│   │   ├── kr_list.csv
│   │   └── nk_list.csv
│   └── dictionaries/
│       ├── tw_list_dictionary.csv
│       ├── kr_list_dictionary.csv
│       └── nk_list_dictionary.csv
├── docs/
│   ├── article.pdf
│   └── SI.pdf
└── LICENSE
```

## Data

Each CSV contains **raw survey responses** in the original language (Mandarin/Korean) with one row per respondent. Variables use semantic names (no raw questionnaire numbers).

| Category | Variables |
|----------|-----------|
| **Identifiers** | `response_id` |
| **List-experiment outcomes** | `list_pride_treatment_arm`, `list_pride_count` (+ sample-specific variants) |
| **Direct outcomes** | `direct_pride_taiwan`, `direct_pride_korea`, `direct_sk_pride`, `direct_nk_pride` |
| **Demographics** | `age`/`birth_year`, `gender`, `education_years`/`education_raw`, `city_raw`/`region_raw` |
| **Identity/political** | `national_identity_strength`, `ideology_raw`/`ideology_scale_raw`, `party_id_raw`/`party_preference_raw` |

All covariate construction (binary indicators, subgroup splits) is performed transparently in `code/01_list_experiments.R`. See `data/dictionaries/` for complete variable definitions.

## Quickstart

```r
# Option 1: One-click (installs dependencies automatically)
source("run_replication.R")

# Option 2: Manual
install.packages(c("dplyr", "ggplot2", "readr", "stringr", "tibble", "list", "tidyr", "mice"))
source("code/run_all.R")
```

```sh
# Option 3: Command line
make
```

Outputs: `outputs/results/` (CSVs) and `outputs/figures/` (PDF).

## Figure Mapping

| Paper Figure | Description | Output file |
|:------------:|-------------|-------------|
| 1 | National pride by identity strength in Taiwan and South Korea | `outputs/figures/Figure 1.pdf` |
| 2 | Pride in being Taiwanese by subjective identity subgroup | `outputs/figures/Figure 2.pdf` |
| 3 | Pride in being Taiwanese by paternal-origin subgroup | `outputs/figures/Figure 3.pdf` |
| 4 | Pride in being Chinese by subjective identity subgroup | `outputs/figures/Figure 4.pdf` |
| 5 | Pride in being South Korean among native South Koreans and North Korean migrants | `outputs/figures/Figure 5.pdf` |

The model estimates and confidence intervals for all five figures are written to
`outputs/results/list_experiment_estimates.csv`.

## Samples

| Sample | Respondents | List items | Recruitment |
|--------|:-----------:|:----------:|-------------|
| Taiwan | 2,050 | 3-item list | Qualtrics online panel |
| South Korea | 1,998 | 4-item list | Qualtrics online panel |
| North Korean migrants | 301 | 3-item list | Woorion NGO |

## Requirements

- **R** >= 4.0
- [`dplyr`](https://dplyr.tidyverse.org/), [`ggplot2`](https://ggplot2.tidyverse.org/), [`readr`](https://readr.tidyverse.org/), [`stringr`](https://stringr.tidyverse.org/), [`tibble`](https://tibble.tidyverse.org/), [`list`](https://cran.r-project.org/package=list), [`tidyr`](https://tidyr.tidyverse.org/), [`mice`](https://cran.r-project.org/package=mice)

## License

This is an Open Access article distributed under the terms of the [Creative Commons Attribution License (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/), which permits unrestricted reuse, distribution, and reproduction in any medium, provided the original work is properly cited.
