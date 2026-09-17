# Known issues

## Hardcoded paths

The following paths are specific to the original compute environment and must
be updated before running:

| File | Line | Path |
|------|------|------|
| `run_abc_full.sh` | SLIM variable | `~/miniconda3/envs/slim_env/bin/slim` |
| `run_pva_full.sh` | SLIM variable | `~/miniconda3/envs/slim_env/bin/slim` |
| `abc_analisis_completo.R` | `setwd()` | `~/part3/6.russfin/simulaciones/abc/abc_harem_out` |
| `extraer_posterior.R` | `setwd()` | `~/part3/6.russfin/simulaciones/abc/` |
| `fig_pva_main.R` | `setwd()` | `~/part3/6.russfin/simulaciones/abc/` |

## Thread count

Both `run_abc_full.sh` and `run_pva_full.sh` set `THREADS=80`, matching the
96-core server used for the original analysis. Adjust to the number of
available cores minus a small buffer (e.g., `nproc - 4`).

## R package versions

The analysis was run with R 4.4.x and `abc` 2.2.1. The `gfit()` function in
`abc` can fail with `subscript out of bounds` at tolerance 0.10 when the
number of accepted simulations is too small relative to the number of PCA
components. This does not affect the results at tolerances 0.01 and 0.05.
