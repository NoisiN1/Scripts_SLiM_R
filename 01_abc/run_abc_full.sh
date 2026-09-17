#!/bin/bash
# ============================================================
# FASE 2: ABC FULL con guanaco_abc_harem_v2.slim
# 40,000 sims (10k por escenario x 4 escenarios de M)
# mu=1.2e-8, BURN=10*max(N,NSOURCE), harem 1:10 discreto
# Priors: N ~ U(500,5000), H ~ U(0.05,0.40), NSOURCE ~ U(500,5000)
# Estimado: ~30-40h en 80 threads
# ============================================================

set -e
cd ~/part3/6.russfin/simulaciones/abc/

SLIM=~/miniconda3/envs/slim_env/bin/slim
NREP=10000
THREADS=80
LOGDIR=logs_abc_$(date +%Y%m%d)
OUTDIR=abc_harem_out
mkdir -p $LOGDIR $OUTDIR

echo "==================================================="
echo "ABC FULL INICIO: $(date)"
echo "  mu=1.2e-8, BURN=10*max(N,NSOURCE) adaptativo"
echo "  Priors: N~U(500,5000), H~U(0.05,0.40), NSOURCE~U(500,5000)"
echo "  4 escenarios x $NREP sims = $((4*NREP)) sims totales"
echo "==================================================="
echo ""

run_scenario() {
    local SCEN=$1
    local MVAL=$2
    local OUT=$OUTDIR/abc_${SCEN}.txt
    > $OUT

    echo "=========================================="
    echo "Escenario: $SCEN (m=$MVAL) - $(date)"
    echo "=========================================="
    START=$(date +%s)

    seq 1 $NREP | xargs -n1 -P$THREADS -I{} bash -c '
        N=$(shuf -i 500-5000 -n 1)
        H=$(awk -v s=$RANDOM "BEGIN{srand(s); print 0.05 + rand()*(0.40-0.05)}")
        NSRC=$(shuf -i 500-5000 -n 1)
        '"$SLIM"' \
            -d "N=$N" \
            -d "H=$H" \
            -d "M='"$MVAL"'" \
            -d "NSOURCE=$NSRC" \
            -d "REP='"{}"'" \
            -d "OUTFILE='"'$OUT'"'" \
            guanaco_abc_harem_v2.slim > /dev/null 2>&1
    '

    END=$(date +%s)
    NLINES=$(wc -l < $OUT)
    ELAPSED=$(( END - START ))
    echo "  Duracion: $(( ELAPSED / 3600 ))h $(( (ELAPSED % 3600) / 60 ))m ($ELAPSED seg)"
    echo "  Sims exitosas: $NLINES / $NREP"
    if [ "$NLINES" -lt "$NREP" ]; then
        echo "  WARN: $((NREP - NLINES)) sims fallaron"
    fi
    echo ""
}

# Ejecutar los 4 escenarios secuencialmente
run_scenario "cerrado"  "0.0"
run_scenario "bajo"     "0.01"
run_scenario "moderado" "0.02"
run_scenario "alto"     "0.05"

# ============================================================
# Consolidar outputs y stats finales
# ============================================================
echo ""
echo "==================================================="
echo "FIN ABC FULL: $(date)"
echo "==================================================="
echo ""
echo "=== TAMANOS DE OUTPUTS ==="
ls -lah $OUTDIR/abc_*.txt

echo ""
echo "=== NUMERO DE LINEAS ==="
for f in $OUTDIR/abc_*.txt; do
    echo "$(basename $f): $(wc -l < $f) lineas"
done

echo ""
echo "=== ESTADISTICAS RAPIDAS POR ESCENARIO ==="
echo "Formato: N H M NSOURCE He_2005 He_2023 Ho_2005 Ho_2023 TajD_2005 TajD_2023 Ne_2005 Ne_2023"
echo ""
for f in $OUTDIR/abc_*.txt; do
    scen=$(basename $f .txt | sed 's/abc_//')
    echo "--- $scen ---"
    awk 'BEGIN{he_sum=0; ne_sum=0; ho_sum=0; n=0; near_target=0}
         {he_sum+=$5; ho_sum+=$7; ne_sum+=$11; n++; if($5>=0.28 && $5<=0.33) near_target++}
         END {
            if(n>0) {
                printf "  n=%d  mean(He_2005)=%.3f  mean(Ho_2005)=%.3f  mean(Ne_2005)=%.0f\n", n, he_sum/n, ho_sum/n, ne_sum/n
                printf "  Sims con He_2005 ~ empirico (0.28-0.33): %d (%.1f%%)\n", near_target, 100.0*near_target/n
            }
         }' $f
done

echo ""
echo "=== SIGUIENTE ==="
echo "Correr Rscript abc_analisis_completo.R para obtener posterior N y Bayes factors"
echo "  cd $OUTDIR && cp ../abc_analisis_completo.R ./"
echo "  Nota: puede necesitar ajustar rutas en el R script"
