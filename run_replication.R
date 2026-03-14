# One-click replication script
# Installs required packages and runs the full analysis pipeline.

cat("Installing required packages...\n")
source("code/requirements.R")

cat("Running analysis pipeline...\n")
source("code/run_all.R")
