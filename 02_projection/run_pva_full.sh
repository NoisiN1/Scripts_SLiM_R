#!/bin/bash
# ============================================================
# PVA FULL con N muestreado del posterior ABC
# 3 escenarios harvest x 3 escenarios migracion = 9 escenarios
# 5000 sims por escenario = 45,000 sims totales
# Estimado: ~10-15h en 80 threads
# ============================================================

set -e
cd ~/part3/6.russfin/simulaciones/abc/

SLIM=~/miniconda3/envs/slim_env/bin/slim
NREP=5000
THREADS=80
LOGDIR=logs_pva_$(date +%Y%m%d)
OUTDIR=pva_out_final
mkdir -p $LOGDIR $OUTDIR

POSTERIOR_FILE=posterior_N_samples.txt

# Verificar que existe el posterior
if [ ! -f "$POSTERIOR_FILE" ]; then
    echo "ERROR: $POSTERIOR_FILE no existe"
    echo "Correr primero: Rscript extraer_posterior.R"
    exit 1
fi

N_POSTERIOR_SIZE=$(wc -l < $POSTERIOR_FILE)
echo "==================================================="
echo "PVA FULL INICIO: $(date)"
echo "  N muestreado del posterior ABC ($N_POSTERIOR_SIZE valores)"
echo "  9 escenarios x $NREP sims = $((9*NREP)) sims totales"
echo "==================================================="
echo ""

run_scenario_pva() {
    local HSCEN=$1
    local HFUT=$2
    local MTAG=$3
    local MVAL=$4
    local OUT=$OUTDIR/pva_${HSCEN}_m${MTAG}.txt
    > $OUT

    echo "=========================================="
    echo "PVA: H=$HSCEN (H_FUT=$HFUT), m=$MVAL - $(date)"
    echo "=========================================="
    START=$(date +%s)

    seq 1 $NREP | xargs -n1 -P$THREADS -I{} bash -c '
        N=$(shuf -n 1 '"$POSTERIOR_FILE"')
        '"$SLIM"' \
            -d "N=$N" \
            -d "H_HIST=0.21" \
            -d "H_FUT='"$HFUT"'" \
            -d "M_FUT='"$MVAL"'" \
            -d "REP='"{}"'" \
            -d "SCEN='"'${HSCEN}_m${MTAG}'"'" \
            -d "OUTFILE='"'$OUT'"'" \
            guanaco_pva_harem_migration.slim > /dev/null 2>&1
    '

    END=$(date +%s)
    NLINES=$(wc -l < $OUT)
    ELAPSED=$(( END - START ))
    echo "  Duracion: $(( ELAPSED/3600 ))h $(( (ELAPSED%3600)/60 ))m ($ELAPSED seg)"
    echo "  Lineas output: $NLINES"
    echo ""
}

# 3 escenarios harvest x 3 escenarios migracion = 9 combinaciones
for HSCEN in bajo actual alto; do
    case $HSCEN in
        bajo)    HFUT=0.105 ;;
        actual)  HFUT=0.21 ;;
        alto)    HFUT=0.42 ;;
    esac
    for MTAG in 0 1 5; do
        case $MTAG in
            0) MVAL=0.0 ;;
            1) MVAL=0.01 ;;
            5) MVAL=0.05 ;;
        esac
        run_scenario_pva "$HSCEN" "$HFUT" "$MTAG" "$MVAL"
    done
done

# Consolidar
cat $OUTDIR/pva_bajo_m*.txt $OUTDIR/pva_actual_m*.txt $OUTDIR/pva_alto_m*.txt > $OUTDIR/pva_todos.txt

echo ""
echo "==================================================="
echo "PVA FULL FIN: $(date)"
echo "==================================================="
echo ""
echo "=== TAMANOS OUTPUTS ==="
ls -lah $OUTDIR/pva_*.txt

echo ""
echo "=== NUMERO DE LINEAS POR ESCENARIO ==="
for f in $OUTDIR/pva_*.txt; do
    echo "$(basename $f): $(wc -l < $f) lineas"
done

echo ""
echo "SIGUIENTE: rehacer figuras heatmap 3x3 + trayectorias 12 paneles"
