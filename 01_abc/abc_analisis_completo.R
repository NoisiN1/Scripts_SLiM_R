# abc_analisis_completo.R
# Analisis completo del ABC nuevo: Bayes factors + GOF + posterior N
# Correr en galeno: cd ~/part3/6.russfin/simulaciones/abc/ && Rscript abc_analisis_completo.R

suppressPackageStartupMessages({
  if (!requireNamespace("abc", quietly = TRUE)) install.packages("abc", repos = "http://cran.r-project.org")
  library(abc)
})

cat("=======================================================\n")
cat("ANALISIS ABC - 3 escenarios (cerrado, bajo, moderado)\n")
cat("=======================================================\n\n")

setwd("~/part3/6.russfin/simulaciones/abc/abc_harem_out")

read_abc <- function(f) {
  read.table(f, header = FALSE, sep = "\t",
    col.names = c("N", "H", "M", "NSOURCE",
                  "He_2005", "He_2023", "Ho_2005", "Ho_2023",
                  "TajD_2005", "TajD_2023", "Ne_2005", "Ne_2023"))
}

cerrado  <- read_abc("abc_cerrado.txt")
bajo     <- read_abc("abc_bajo.txt")
moderado <- read_abc("abc_moderado.txt")

cat("Sims cargadas: cerrado=", nrow(cerrado),
    " bajo=", nrow(bajo),
    " moderado=", nrow(moderado), "\n\n", sep = "")

target <- c(He_2005 = 0.302, He_2023 = 0.304,
            Ho_2005 = 0.292, Ho_2023 = 0.301,
            Ne_2005 = 1006,  Ne_2023 = 568)

use_cols <- names(target)
cat("Targets empiricos usados:\n")
print(target); cat("\n")

scenarios <- list(cerrado = cerrado, bajo = bajo, moderado = moderado)
model_labels <- rep(names(scenarios), sapply(scenarios, nrow))
sumstats_all <- do.call(rbind, lapply(scenarios, function(d) d[, use_cols]))

cat("Total sims combinadas:", nrow(sumstats_all), "\n\n")

cat("=======================================================\n")
cat("MODEL SELECTION (postpr, rejection, tol=0.05)\n")
cat("=======================================================\n\n")

modsel <- postpr(target, model_labels, sumstats_all,
                 tol = 0.05, method = "rejection")
print(summary(modsel))
cat("\n")

cat("Bayes factors (vs cerrado):\n")
probs <- summary(modsel)$Prob
bf <- probs / probs["cerrado"]
print(round(bf, 3)); cat("\n")

cat("=======================================================\n")
cat("GOODNESS-OF-FIT (gfitpca) - 3 tolerancias\n")
cat("=======================================================\n\n")

gof_results <- matrix(NA, nrow = 3, ncol = 3,
                     dimnames = list(names(scenarios),
                                     c("tol=0.01", "tol=0.05", "tol=0.10")))
for (sc in names(scenarios)) {
  for (tol_v in c(0.01, 0.05, 0.10)) {
    tryCatch({
      g <- gfit(target = target,
                sumstat = scenarios[[sc]][, use_cols],
                nb.replicate = 100, tol = tol_v)
      gof_results[sc, paste0("tol=", tol_v)] <- summary(g)$pvalue
    }, error = function(e) {
      cat("  Error gfit", sc, "tol=", tol_v, ":", conditionMessage(e), "\n")
    })
  }
}
print(round(gof_results, 3))
cat("\nInterpretacion: p > 0.05 = modelo compatible con datos\n\n")

winner <- names(which.max(probs))
cat("=======================================================\n")
cat("POSTERIOR DEL ESCENARIO GANADOR:", winner, "\n")
cat("=======================================================\n\n")

d_win <- scenarios[[winner]]
posterior <- abc(target = target,
                 param = d_win[, c("N", "H", "NSOURCE")],
                 sumstat = d_win[, use_cols],
                 tol = 0.05, method = "rejection")
cat("Posterior summary (rejection, tol=0.05):\n")
print(summary(posterior))
cat("\n")

cat("=======================================================\n")
cat("CROSS-VALIDATION ERRORS (100 iter, 3 tolerancias)\n")
cat("=======================================================\n\n")

cv_res <- cv4abc(param = d_win[, c("N", "H", "NSOURCE")],
                 sumstat = d_win[, use_cols],
                 nval = 100,
                 tols = c(0.01, 0.05, 0.10),
                 method = "rejection")
print(summary(cv_res))
cat("\nInterpretacion: valores cercanos a 0 = parametro identificable\n\n")

saveRDS(list(modsel = modsel, gof = gof_results,
             posterior = posterior, cv = cv_res,
             winner = winner, target = target),
        "~/part3/6.russfin/simulaciones/abc/abc_analisis_resultados.rds")

cat("=======================================================\n")
cat("Guardado en: abc_analisis_resultados.rds\n")
cat("=======================================================\n")
