#!/usr/bin/env Rscript
# abc_analisis_wf_tolerancias.R
# ABC WF: estimacion con 3 tolerancias (0.005, 0.01, 0.05) para tabla del paper.
# Resultados: GOF, cross-validation, posteriors N y H, tabla y figura.

suppressMessages({ library(abc); library(dplyr) })
select <- dplyr::select; filter <- dplyr::filter
mutate <- dplyr::mutate; summarise <- dplyr::summarise
set.seed(123)

# Datos
ref <- read.table("referencia_abc.txt", header=TRUE, sep="\t")
cat("Simulaciones:", nrow(ref), "\n")
ref <- ref %>% filter(complete.cases(.), He_2005>0, He_2023>0)
cat("Tras limpieza:", nrow(ref), "\n")

param_N <- ref[, "N", drop=FALSE]
param_H <- ref[, "H", drop=FALSE]
stat_cols <- c("He_2005","He_2023","Ho_2005","Ho_2023",
               "TajD_2005","TajD_2023","Ne_2005","Ne_2023")
sumstat <- ref[, stat_cols]

target <- data.frame(He_2005=0.302, He_2023=0.304, Ho_2005=0.292, Ho_2023=0.301,
                     TajD_2005=0.165, TajD_2023=0.169, Ne_2005=887, Ne_2023=956)

# GOF
cat("\n=== GOF ===\n")
gof <- gfit(target=target, sumstat=sumstat, nb.replicate=100, tol=0.01, statistic=median)
cat(sprintf("p-value GOF = %.3f\n", summary(gof)$pvalue))

# Cross-validation 3 tolerancias
cat("\n=== CROSS-VALIDATION ===\n")
tolerancias <- c(0.005, 0.01, 0.05)
cv_N <- cv4abc(param=param_N, sumstat=sumstat, nval=100, tols=tolerancias, method="loclinear")
cat("Error de prediccion N:\n"); print(summary(cv_N))

# Estimaciones por tolerancia (rejection, robusto)
cat("\n=== POSTERIORS POR TOLERANCIA ===\n")
tabla <- data.frame()
for (tol in tolerancias) {
  res_N <- abc(target=target, param=param_N, sumstat=sumstat, tol=tol, method="rejection")
  post_N <- res_N$unadj.values[,1]
  res_H <- abc(target=target, param=param_H, sumstat=sumstat, tol=tol, method="rejection")
  post_H <- res_H$unadj.values[,1]
  fila <- data.frame(
    Tolerance = tol,
    N_accepted = length(post_N),
    N_median = round(median(post_N), 1),
    N_mean = round(mean(post_N), 1),
    N_q025 = round(quantile(post_N, 0.025), 1),
    N_q975 = round(quantile(post_N, 0.975), 1),
    H_median = round(median(post_H), 3),
    H_mean = round(mean(post_H), 3),
    H_q025 = round(quantile(post_H, 0.025), 3),
    H_q975 = round(quantile(post_H, 0.975), 3)
  )
  tabla <- rbind(tabla, fila)
}
cat("\nTabla para el paper:\n")
print(tabla)
write.csv(tabla, "ABC_WF_tabla_3tolerancias.csv", row.names=FALSE)

# Guardar el posterior final (tol=0.01) para proyecciones
tol_final <- 0.01
res_N_final <- abc(target=target, param=param_N, sumstat=sumstat, tol=tol_final, method="rejection")
res_H_final <- abc(target=target, param=param_H, sumstat=sumstat, tol=tol_final, method="rejection")
write.csv(data.frame(N=res_N_final$unadj.values[,1]), "ABC_WF_posterior_N.csv", row.names=FALSE)
write.csv(data.frame(H=res_H_final$unadj.values[,1]), "ABC_WF_posterior_H.csv", row.names=FALSE)

cat("\n=== LISTO ===\n")
cat("Archivos:\n")
cat("  ABC_WF_tabla_3tolerancias.csv  <- TABLA PARA PAPER\n")
cat("  ABC_WF_posterior_N.csv  <- posterior de N (para proyecciones)\n")
cat("  ABC_WF_posterior_H.csv  <- posterior de H (para proyecciones)\n")
