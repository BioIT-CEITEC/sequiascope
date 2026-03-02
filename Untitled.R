library(data.table)

set.seed(123)

infile  <- "input_files/demo_data/expressions/DZ1601/DZ1601_spleen.tsv"
outfile <- "input_files/demo_data/expressions/DZ1601/DZ1601_spleen1.tsv"

dt <- fread(infile, sep = "\t", header = TRUE)
dt[, log2FC := as.numeric(log2FC)]

sample_n_or_all <- function(x, n = 10) {
  k <- min(n, nrow(x))
  if (k == 0) return(x)
  x[sample.int(nrow(x), k)]
}

dt_hi  <- sample_n_or_all(dt[log2FC >  1], 10)
dt_lo  <- sample_n_or_all(dt[log2FC < -1], 10)
dt_mid <- sample_n_or_all(dt[log2FC > -1 & log2FC < 1], 10)

dt_out <- rbindlist(list(dt_hi, dt_lo, dt_mid), use.names = TRUE, fill = TRUE)

# seřazení podle Ensembl ID (u tebe sloupec geneid)
setorder(dt_out, geneid)

fwrite(dt_out, outfile, sep = "\t", quote = FALSE, na = "NA")
