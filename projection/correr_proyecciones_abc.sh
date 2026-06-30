#!/bin/bash
# correr_proyecciones_abc.sh
# Proyecta 1000 trayectorias muestreando N y H del posterior del ABC WF.
# Cada simulacion es independiente: sortea un (N, H) y proyecta a +108 anos.

NREP=1000
HILOS=45
POST_DIR="abc"
OUTFILE="resultados_proyeccion_abc.txt"

HEADER="rep\tN\tH\tPi_2005\tPi_2023\tPi_18\tPi_36\tPi_54\tPi_72\tPi_90\tPi_108\tHe_2005\tHe_2023\tHe_18\tHe_36\tHe_54\tHe_72\tHe_90\tHe_108\tHo_2005\tHo_2023\tHo_18\tHo_36\tHo_54\tHo_72\tHo_90\tHo_108\tTajD_2005\tTajD_2023\tTajD_18\tTajD_36\tTajD_54\tTajD_72\tTajD_90\tTajD_108"

echo "=== PROYECCION JUSTIFICADA POR ABC - $NREP simulaciones ==="
rm -f proy_*.tmp errores_proy.log

# Pre-muestrear N y H del posterior (con reemplazo)
Rscript - << RSCRIPT
set.seed(42)
post_N <- read.csv("${POST_DIR}/ABC_WF_posterior_N.csv")
post_H <- read.csv("${POST_DIR}/ABC_WF_posterior_H.csv")
idx_N <- sample(1:nrow(post_N), $NREP, replace=TRUE)
idx_H <- sample(1:nrow(post_H), $NREP, replace=TRUE)
samples <- data.frame(
  REP = 1:$NREP,
  N = round(post_N\$N[idx_N]),
  H = round(post_H\$H[idx_H], 4)
)
# N debe ser entero positivo (puede haber valores muy bajos del posterior)
samples\$N[samples\$N < 30] <- 30
write.table(samples, "muestras_posterior.txt", row.names=FALSE, col.names=FALSE, quote=FALSE, sep="\t")
cat("Muestras generadas:", nrow(samples), "\n")
cat("N: rango", range(samples\$N), "mediana", median(samples\$N), "\n")
cat("H: rango", range(samples\$H), "mediana", median(samples\$H), "\n")
RSCRIPT

# Worker que lee REP, N, H y corre la simulacion
cat > worker_proy.sh << 'EOF'
#!/bin/bash
REP=$1; N=$2; H=$3
out="proy_${REP}.tmp"
slim -define "N=${N}" -define "H=${H}" -define "REP=${REP}" -define "OUTFILE='${out}'" guanaco_proyeccion_abc.slim > /dev/null 2>&1
if [[ ! -f "$out" ]]; then echo "ERROR rep ${REP} (N=$N H=$H)" >> errores_proy.log; fi
EOF
chmod +x worker_proy.sh

echo "-> Lanzando $NREP simulaciones en $HILOS hilos..."
cat muestras_posterior.txt | xargs -P $HILOS -n 3 ./worker_proy.sh

echo "-> Consolidando..."
echo -e "$HEADER" > "$OUTFILE"
for (( i=1; i<=NREP; i++ )); do
    if [[ -f "proy_${i}.tmp" ]]; then
        cat "proy_${i}.tmp" >> "$OUTFILE"
        rm -f "proy_${i}.tmp"
    fi
done
rm -f worker_proy.sh muestras_posterior.txt

n_ok=$(($(wc -l < "$OUTFILE") - 1))
echo "LISTO! $n_ok proyecciones validas en $OUTFILE"
