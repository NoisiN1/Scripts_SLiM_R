#!/bin/bash
# generar_referencia.sh
# Tabla de referencia ABC con 4 estadísticos (He, Ho, TajD, Ne) en 2005 y 2023.
# Sortea N ~ Uniforme(300, 2000) y H ~ Uniforme(0.05, 0.40).

NSIM=50000
HILOS=45

N_MIN=300
N_MAX=2000
H_MIN=0.05
H_MAX=0.40

OUTFILE="referencia_abc.txt"
HEADER="N\tH\tHe_2005\tHe_2023\tHo_2005\tHo_2023\tTajD_2005\tTajD_2023\tNe_2005\tNe_2023"

echo "=================================================="
echo "   TABLA DE REFERENCIA ABC - $NSIM simulaciones"
echo "   (4 estadísticos x 2 tiempos)"
echo "=================================================="

rm -f ref_*.tmp

cat << 'EOF' > worker_abc.sh
#!/bin/bash
i=$1
N_MIN=$2; N_MAX=$3; H_MIN=$4; H_MAX=$5
N=$(awk -v min=$N_MIN -v max=$N_MAX -v seed=$RANDOM 'BEGIN{srand(seed); print int(min + rand()*(max-min))}')
H=$(awk -v min=$H_MIN -v max=$H_MAX -v seed=$RANDOM 'BEGIN{srand(seed+1); printf "%.4f", min + rand()*(max-min)}')
out="ref_${i}.tmp"
slim -define "N=${N}" -define "H=${H}" -define "REP=${i}" -define "OUTFILE='${out}'" guanaco_abc.slim > /dev/null 2>&1
if [[ ! -f "$out" ]]; then
    echo "ERROR sim $i (N=$N H=$H)" >> errores_abc.log
fi
EOF
chmod +x worker_abc.sh

echo "-> Lanzando $NSIM simulaciones en $HILOS hilos..."
seq 1 $NSIM | xargs -P $HILOS -I {} ./worker_abc.sh {} $N_MIN $N_MAX $H_MIN $H_MAX

echo "-> Consolidando tabla de referencia..."
echo -e "$HEADER" > "$OUTFILE"
for (( i = 1; i <= NSIM; i++ )); do
    if [[ -f "ref_${i}.tmp" ]]; then
        cat "ref_${i}.tmp" >> "$OUTFILE"
        rm -f "ref_${i}.tmp"
    fi
done

rm -f worker_abc.sh
n_ok=$(($(wc -l < "$OUTFILE") - 1))
echo "LISTO! $n_ok simulaciones validas en $OUTFILE"
