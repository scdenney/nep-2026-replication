.PHONY: all clean

all:
	Rscript run_replication.R

clean:
	rm -rf outputs/
