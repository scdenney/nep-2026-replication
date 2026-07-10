# Replication Package Confirmation

Package: Replication materials for "Identity Conformity in Taiwan and South Korea: Why Citizens in Divided Societies Are Pressured to Overstate National Pride"

Article DOI: https://doi.org/10.1080/13537113.2026.2616954

Dataverse DOI: https://doi.org/10.7910/DVN/ZSYQVF

Verified: 2026-05-16

## Scope

This package reproduces the five published list-experiment figures for the article. It does not include conjoint-analysis scripts because the article and this replication package concern list experiments.

The public replication path is:

```r
source("run_replication.R")
```

The command installs or loads required R packages and runs `code/run_all.R`, which verifies inputs and runs `code/01_list_experiments.R`.

## Standards Followed

The package has been checked against the following replication and open-science standards:

- one documented public entry point;
- relative paths from the package root;
- public analysis-ready data files included in `data/samples/`;
- data dictionaries included in `data/dictionaries/`;
- clear README with article citation, data description, software requirements, run instructions, and figure mapping;
- generated results written to `outputs/results/`;
- generated figures written to `outputs/figures/`;
- input checksum log written to `outputs/logs/input_md5.csv`;
- R session information written to `outputs/logs/sessionInfo.txt`;
- no API tokens, credentials, private paths, or restricted raw inputs included in the public archive;
- files organized so the Dataverse download can be run from a clean directory.

The package follows the FAIR principles in practical replication terms:

- Findable: the article and data archive have persistent DOI links and citation metadata.
- Accessible: the public package can be downloaded and run without private credentials.
- Interoperable: data are provided in delimited text files with dictionaries, and code uses relative paths.
- Reusable: the package documents dependencies, records checksums and session information, and regenerates the paper figures from scripts.

## Package Conventions

The general Replication Package Guide recommends `master.R` as the default entry point. This archive uses `run_replication.R` because that was the established public-package convention for this Dataverse record. It performs the same role: one command from the package root runs the complete public replication path.

Harvard Dataverse may expose ingested tabular data with `.tab` labels even when the uploaded source files were `.csv`. The public scripts therefore accept both `.csv` and `.tab` filenames and detect delimiters from file content.

## Verification Performed

The package was verified in three ways:

1. The local package was run from the repository root.
2. The upload-ready Dataverse staging package was run from a clean temporary directory.
3. The published Harvard Dataverse package was downloaded through the API into a clean temporary directory and run with `Rscript run_replication.R`.

The public Dataverse package regenerated:

- `outputs/results/list_experiment_estimates.csv`
- `outputs/figures/Figure 1.pdf`
- `outputs/figures/Figure 2.pdf`
- `outputs/figures/Figure 3.pdf`
- `outputs/figures/Figure 4.pdf`
- `outputs/figures/Figure 5.pdf`
- `outputs/logs/input_md5.csv`
- `outputs/logs/sessionInfo.txt`

The regenerated `list_experiment_estimates.csv` had 61 lines, including the header, and matched the verified local output checksum at the time of release:

```text
d342dbe90be0d9a1a84ec0cd6f2e9125
```

## Correction Note

The corrected Dataverse package fixes non-substantive replication-package preparation issues in file organization, input handling, and replication scripts so the public archive reproduces the published list-experiment figures. These corrections do not affect the article's data, estimates, substantive conclusions, or published results.
