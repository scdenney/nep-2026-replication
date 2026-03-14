#!/usr/bin/env Rscript

required_files <- c(
  "data/samples/tw_list.csv",
  "data/samples/kr_list.csv",
  "data/samples/nk_list.csv",
  "docs/article.pdf",
  "docs/SI.pdf"
)

missing <- required_files[!file.exists(required_files)]
if (length(missing) > 0) {
  stop("Missing required files:\n", paste0("- ", missing, collapse = "\n"), call. = FALSE)
}

if (!dir.exists(file.path("outputs", "logs"))) {
  dir.create(file.path("outputs", "logs"), recursive = TRUE)
}

hashes <- tools::md5sum(required_files)
out <- data.frame(path = names(hashes), md5 = as.character(hashes), row.names = NULL)
write.csv(out, file = file.path("outputs", "logs", "input_md5.csv"), row.names = FALSE)

message("Input verification complete. Wrote outputs/logs/input_md5.csv")
