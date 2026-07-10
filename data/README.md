# Data Inventory

One shareable analysis file per sample. Each file includes:
- Direct-question outcomes used in list-experiment models
- List-experiment treatment/count variables
- Expanded demographic/background covariates
- Semantic variable names (no raw questionnaire-number codes)

## Data files

| File | Sample | Respondents |
|------|--------|:-----------:|
| `samples/tw_list.csv` | Taiwan | 2,050 |
| `samples/kr_list.csv` | South Korea | 1,998 |
| `samples/nk_list.csv` | North Korean migrants | 301 |

## Data dictionaries

- `dictionaries/tw_list_dictionary.csv`
- `dictionaries/kr_list_dictionary.csv`
- `dictionaries/nk_list_dictionary.csv`

## Build/rebuild

To regenerate sample files from the local raw archive (requires private `data/full_raw_archive/`):

```bash
Rscript code/00_build_samples.R
```

The raw archive is git-ignored and not part of the shareable package.
