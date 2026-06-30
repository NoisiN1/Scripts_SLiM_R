#!/usr/bin/env Rscript
# Posterior predictive check: el ABC reproduce los datos de 2005 y 2023?
suppressMessages({ library(abc); library(dplyr) })
select <- dplyr::select; filter <- dplyr::filter
mutate <- dplyr::mutate; summarise <- dplyr::summarise
set.seed(123)

ref <- read.table("referencia_abc.txt", header=TRUE, sep="\t") %>%
  filter(complete.cases(.), He_2005>0, He_2023>0)
param_N <- ref[, "N", drop=FALSE]
stat_cols <- c("He_2005","He_2023","Ho_2005","Ho_2023",
               "TajD_2005","TajD_2023","Ne_2005","Ne_2023")
sumstat <- ref[, stat_cols]
target <- data.frame(He_2005=0.302, He_2023=0.304, Ho_2005=0.292, Ho_2023=0.301,
                     TajD_2005=0.165, TajD_2023=0.169, Ne_2005=887, Ne_2023=956)

# ABC rejection con tol=0.01 (la del paper)
res <- abc(target=target, param=param_N, sumstat=sumstat, tol=0.01, method="rejection")
acc <- res$region  # indices de simulaciones aceptadas
sumstat_acc <- sumstat[acc, ]

cat("=== POSTERIOR PREDICTIVE CHECK ===\n")
cat("Simulaciones aceptadas:", sum(acc), "\n\n")
cat(sprintf("%-12s %-15s %-25s %s\n",
            "Estadistico", "Empirico", "Simulado [mediana IC95%]", "Esta dentro?"))
cat(paste(rep("-", 75), collapse=""), "\n")

for (stat in stat_cols) {
  emp <- target[[stat]]
  sim_med <- median(sumstat_acc[[stat]])
  sim_q025 <- quantile(sumstat_acc[[stat]], 0.025)
  sim_q975 <- quantile(sumstat_acc[[stat]], 0.975)
  ok <- ifelse(emp >= sim_q025 & emp <= sim_q975, "SI ✓", "NO ✗")
  if (grepl("Ne", stat)) {
    cat(sprintf("%-12s %-15.1f %-25s %s\n",
                stat, emp,
                sprintf("%.1f [%.1f, %.1f]", sim_med, sim_q025, sim_q975), ok))
  } else {
    cat(sprintf("%-12s %-15.3f %-25s %s\n",
                stat, emp,
                sprintf("%.3f [%.3f, %.3f]", sim_med, sim_q025, sim_q975), ok))
  }
}
