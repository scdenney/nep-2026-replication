required_packages <- c(
  "dplyr",
  "ggplot2",
  "readr",
  "stringr",
  "tibble",
  "list",
  "tidyr",
  "mice"
)

options(repos = c(CRAN = "https://cloud.r-project.org"))

missing <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  install.packages(missing)
}

invisible(lapply(required_packages, library, character.only = TRUE))
