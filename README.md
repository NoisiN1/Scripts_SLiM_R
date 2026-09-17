# SLiM forward simulations + ABC — Guanaco harvest PVA (Russfin, Tierra del Fuego)

Scripts to reproduce the forward genetic simulations (SLiM 5.1), Approximate
Bayesian Computation (ABC) inference, and Population Viability Analysis (PVA)
reported in:

> Peña-Monroy A., Flores-Morales G., Leggieri L., Soto N., Quilodrán C. S.,
> Orozco-terWengel P. & Marín J. C. *Empirical stability and projected
> fragility under regulated harvest: an 18-year genomic test in the largest
> insular guanaco population.* Scientific Reports (in revision).

## Repository layout

```
.
├── 01_abc/                          ABC model selection (closed vs. migration)
│   ├── guanaco_abc.slim               Original ABC (WF, closed, μ = 1.2 × 10⁻⁸)
│   ├── guanaco_abc_harem_v2.slim      Extended ABC (nonWF, harem 1:10, 4 migration
│   │                                    scenarios, adaptive burn-in)
│   ├── run_abc_full.sh                Parallel runner: 40,000 sims (10 k × 4 scenarios)
│   └── abc_analisis_completo.R        Model selection, GOF, posterior, cross-validation
│
├── 02_projection/                   Forward PVA (harvest × migration matrix)
│   ├── guanaco_pva_harem_discrete.slim  PVA closed (nonWF, harem, 3 harvest levels)
│   ├── guanaco_pva_harem_migration.slim PVA with bidirectional migration (3 × 3 matrix)
│   ├── extraer_posterior.R              Extract posterior N samples for PVA input
│   └── run_pva_full.sh                  Parallel runner: 45,000 sims (5 k × 9 scenarios)
│
├── 03_figures/                      Figures and tables
│   └── fig_pva_main.R                 Fig. X — projected π, Ho, He trajectories
│
├── .gitignore
├── KNOWN_ISSUES.md
└── README.md
```

## Model specification

### Genomic parameters

| Parameter | Value | Reference / Notes |
| :--- | :--- | :--- |
| Mutation rate (μ) | 1.2 × 10⁻⁸ /site/generation | [Fan et al. 2020](https://doi.org/10.1186/s13059-020-02080-6) |
| Recombination rate (ρ) | 1.2 × 10⁻⁸ /site/generation | Set equal to μ (neutral) |
| Simulated region | 100,000 bp | Neutral, infinite-sites |
| Generation time | 4.5 years | [Leggieri et al. 2024](https://doi.org/10.1093/biolinnean/blae087) |

### Demographic model

| Component | Implementation |
|-----------|---------------|
| Framework | SLiM 5.1, non-Wright–Fisher (nonWF) |
| Sex structure | Two sexes (1:1 ratio) |
| Mating system | Discrete harem: 1 territorial ♂ + up to 10 ♀ |
| Offspring | Poisson(λ = 1.8) per ♀ per generation |
| Density regulation | fitnessScaling = K / N |
| Burn-in | Adaptive: 10 × max(K, K_source) generations |

### ABC design (`01_abc/`)

| Item | Value |
|------|-------|
| Priors | N ~ U(500, 5 000); H ~ U(0.05, 0.40); N_source ~ U(500, 5 000) |
| Migration scenarios | m ∈ {0, 0.01, 0.02, 0.05} (fixed per scenario) |
| Summary statistics | He, Ho (fixed SNP panel), Ne = π/(4μ), at 2005 and 2023 |
| Simulations | 10,000 per scenario × 4 = 40,000 total |
| Analysis | Rejection ABC (tol = 0.05), GOF (gfitpca), cross-validation |

### PVA design (`02_projection/`)

| Item | Value |
|------|-------|
| Initial N | Sampled from ABC posterior (median 2,972; 95 % CI [1,293–4,820]) |
| Historical harvest (2005–2023) | H = 0.21/gen (SAG quota, 4.2 %/year) |
| Future harvest | H ∈ {0.105, 0.21, 0.42} (low, current, high) |
| Future migration | m ∈ {0, 0.01, 0.05} (closed, low, high) |
| Projection horizon | 24 generations (108 years, to 2131) |
| Simulations | 5,000 per scenario × 9 = 45,000 total |

## Order of execution

1. **`01_abc/`** — run the ABC to select the best demographic model and estimate N.
   1. `bash run_abc_full.sh` — launches 40,000 SLiM simulations (≈ 35 h on 80 cores).
   2. `Rscript abc_analisis_completo.R` — model selection, GOF, posterior extraction.
2. **`02_projection/`** — run the forward PVA using the ABC posterior.
   1. `Rscript extraer_posterior.R` — writes `posterior_N_samples.txt` (500 draws).
   2. `bash run_pva_full.sh` — launches 45,000 SLiM simulations (≈ 44 h on 80 cores).
3. **`03_figures/`** — generate manuscript figures.
   1. `Rscript fig_pva_main.R` — Fig. X (π, Ho, He trajectories with migration scenarios).

## Script → manuscript mapping

| Manuscript item | Script |
|-----------------|--------|
| Fig. 5 — Projected genetic diversity (π, Ho, He) | `03_figures/fig_pva_main.R` |
| Fig. S2 — ABC model selection (Bayes factors + GOF) | `01_abc/abc_analisis_completo.R` |
| Fig. S3 — Posterior distributions (N, H) | `01_abc/abc_analisis_completo.R` |
| Table S3 — ABC priors and parameters | (documented in `01_abc/guanaco_abc_harem_v2.slim`) |
| Table S4 — Cross-validation errors | `01_abc/abc_analisis_completo.R` |

## Software requirements

- **SLiM 5.1** (Haller et al., 2026)
- **R ≥ 4.0** with packages: `abc`, `ggplot2`, `cowplot`
- **Bash** + GNU coreutils + `xargs` (for parallel execution)

## Known issues

See `KNOWN_ISSUES.md` for hardcoded paths that need adjustment before the
pipeline can run in a new environment.

## Licence

Code: MIT. Empirical data released under CC-BY 4.0 via a separate archive.
