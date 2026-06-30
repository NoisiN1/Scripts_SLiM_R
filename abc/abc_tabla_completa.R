#!/usr/bin/env Rscript
suppressMessages({ library(abc); library(dplyr) })
select <- dplyr::select; filter <- dplyr::filter
mutate <- dplyr::mutate; summarise <- dplyr::summarise
set.seed(123)

moda_kde <- function(x) {
  d <- density(x)
  d$x[which.max(d$y)]
}

ref <- read.table("referencia_abc.txt", header=TRUE, sep="\t") %>%
  filter(complete.cases(.), He_2005>0, He_2023>0)
param_N <- ref[, "N", drop=FALSE]
param_H <- ref[, "H", drop=FALSE]
stat_cols <- c("He_2005","He_2023","Ho_2005","Ho_2023",
               "TajD_2005","TajD_2023","Ne_2005","Ne_2023")
sumstat <- ref[, stat_cols]
target <- data.frame(He_2005=0.302, He_2023=0.304, Ho_2005=0.292, Ho_2023=0.301,
                     TajD_2005=0.165, TajD_2023=0.169, Ne_2005=887, Ne_2023=956)

tolerancias <- c(0.005, 0.01, 0.05)
tabla <- data.frame()

for (tol in tolerancias) {
  cat("Procesando tolerancia", tol, "\n")
  gof <- gfit(target=target, sumstat=sumstat, nb.replicate=100, tol=tol, statistic=median)
  gof_p <- summary(gof)$pvalue
  res_N <- abc(target=target, param=param_N, sumstat=sumstat, tol=tol, method="rejection")
  res_H <- abc(target=target, param=param_H, sumstat=sumstat, tol=tol, method="rejection")
  post_N <- res_N$unadj.values[,1]
  post_H <- res_H$unadj.values[,1]

  fila <- data.frame(
    Tolerance = tol,
    N_accepted = length(post_N),
    GOF_pvalue = round(gof_p, 3),
    N_median = round(median(post_N), 1),
    N_mean = round(mean(post_N), 1),
    N_mode = round(moda_kde(post_N), 1),
    N_q025 = round(quantile(post_N, 0.025), 1),
    N_q975 = round(quantile(post_N, 0.975), 1),
    H_median = round(median(post_H), 3),
    H_mean = round(mean(post_H), 3),
    H_mode = round(moda_kde(post_H), 3),
    H_q025 = round(quantile(post_H, 0.025), 3),
    H_q975 = round(quantile(post_H, 0.975), 3),
    P_Ne_lt_1000 = round(mean(post_N < 1000), 3)
  )
  tabla <- rbind(tabla, fila)
}

cat("\n=== TABLA COMPLETA ===\n\n"); print(tabla)
write.csv(tabla, "ABC_tabla_completa.csv", row.names=FALSE)

cat("\n=== VERSION COMPACTA ===\n\n")
tabla_paper <- tabla %>%
  mutate(
    N_estimate = sprintf("%.0f [%.0f, %.0f]", N_median, N_q025, N_q975),
    H_estimate = sprintf("%.2f [%.2f, %.2f]", H_median, H_q025, H_q975),
    Tol_pct = paste0(Tolerance*100, "%")
  ) %>%
  select(Tolerance=Tol_pct, N_accepted, GOF_pvalue,
         N_estimate, H_estimate, P_Ne_lt_1000)
print(tabla_paper)
write.csv(tabla_paper, "ABC_tabla_paper.csv", row.names=FALSE)
