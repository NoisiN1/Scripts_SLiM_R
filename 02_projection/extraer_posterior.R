# Extraer posterior de N del ABC ganador (cerrado) y guardar como texto
# para uso en bash (shuf -e) durante las PVA

suppressPackageStartupMessages(library(abc))
setwd("~/part3/6.russfin/simulaciones/abc/")

res <- readRDS("abc_final_4esc.rds")
post <- res$posterior

# Los 500 samples del posterior estan en unadj.values
N_samples <- round(post$unadj.values[, "N"])  # redondear a entero para shuf

cat("Posterior N: n=", length(N_samples), "\n", sep="")
cat("  Min:    ", min(N_samples), "\n", sep="")
cat("  Median: ", median(N_samples), "\n", sep="")
cat("  Max:    ", max(N_samples), "\n", sep="")
cat("  95% CI: [", quantile(N_samples, 0.025), ", ", quantile(N_samples, 0.975), "]\n", sep="")

# Guardar 1 valor por linea (para shuf -n 1 en bash)
writeLines(as.character(N_samples), "posterior_N_samples.txt")
cat("\nGuardado en: posterior_N_samples.txt (", length(N_samples), " valores)\n", sep="")
