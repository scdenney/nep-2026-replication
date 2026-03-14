#!/usr/bin/env Rscript

dir.create(file.path("outputs", "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("outputs", "results"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("outputs", "figures"), recursive = TRUE, showWarnings = FALSE)

message("Verifying required inputs...")
source(file.path("code", "00_verify_inputs.R"), local = new.env())

message("Running list experiment analysis...")
source(file.path("code", "01_list_experiments.R"), local = new.env())

sink(file.path("outputs", "logs", "sessionInfo.txt"))
print(sessionInfo())
sink()

message("Saved: outputs/logs/sessionInfo.txt")
message("Done.")
