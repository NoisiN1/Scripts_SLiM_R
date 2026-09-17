# Bioinformatics pipeline: from raw ddRAD-seq reads to analytical datasets

## Overview

Three analytical datasets (A, B, C) were generated in parallel from a common
upstream pipeline applied to double-digest RAD sequencing (ddRAD-seq) data
from 40 guanaco individuals (20 from 2005, 20 from 2023).

```
Raw FASTQ ──► Demultiplex ──► Trim ──► Align ──► Call variants ──► Filter
                                                                     │
                                                        ┌────────────┼────────────┐
                                                        ▼            ▼            ▼
                                                    Dataset A    Dataset B    Dataset C
                                                    3,406 SNPs   231,969 SNPs  663,989 sites
                                                    (structure)  (Ne, ROH)    (π, He, Ho)
```

## Software versions

| Software | Version | Purpose |
|----------|---------|---------|
| STACKS | 2.65 | Demultiplexing (`process_radtags`) |
| fastp | 0.23.x | Quality trimming and adapter removal |
| BWA-MEM | 0.7.17 | Read alignment |
| SAMtools | 1.17 | BAM processing, sorting, indexing |
| FreeBayes | 1.3.6 | Variant calling (parallelized) |
| VCFtools | 0.1.16 | VCF filtering |
| bcftools | 1.17 | VCF manipulation |
| PLINK | 1.9 | LD pruning |
| pixy | 2.2.3 | Unbiased π, dxy, Fst (Dataset C) |
| Stacks `populations` | 2.69 | Ho, He (Dataset C) |
| currentNe2 | 2.0 | LD-based Ne estimation (Dataset B) |
| RADSex | — | Molecular sexing |

## Reference genome

*Camelus dromedarius* chromosome-level assembly (GCA_036321535.1). Mapping
efficacy >99% for *Lama guanicoe* ddRAD-seq reads (mean MAPQ = 56.66; mean
depth = 4.68×, range 2.27–9.93×).

## Step-by-step pipeline

### 1. Demultiplexing

```bash
process_radtags -p raw/ -o demux/ -b barcodes.txt \
  --renz_1 pstI --renz_2 mspI \
  -c -q -r --inline_null
```

### 2. Quality trimming

```bash
fastp -i demux/{sample}.fq.gz -o trimmed/{sample}.fq.gz \
  --qualified_quality_phred 15 \
  --length_required 50 \
  --adapter_sequence auto
```

### 3. Alignment

```bash
bwa mem -t 8 reference/CamDro.fa trimmed/{sample}.fq.gz \
  | samtools sort -@ 4 -o bam/{sample}.sorted.bam
samtools index bam/{sample}.sorted.bam
```

### 4. Variant calling

```bash
freebayes-parallel <(fasta_generate_regions.py reference/CamDro.fa.fai 100000) 36 \
  -f reference/CamDro.fa \
  --report-monomorphic \
  bam/*.sorted.bam > raw_variants.vcf
```

Note: `--report-monomorphic` generates the all-sites VCF required for Dataset C.

### 5. Common filtering (applied to all datasets)

| Step | Filter | Tool | Command | Sites |
|------|--------|------|---------|-------|
| 5.1 | Raw variants + invariants | FreeBayes | `--report-monomorphic` | 45,945,204 |
| 5.2 | Autosomes only (36 scaffolds) | bcftools | `bcftools view -t CM070310.1,...,CM070345.1` | — |
| 5.3 | Quality ≥ 30, biallelic | VCFtools | `--minQ 30 --min-alleles 2 --max-alleles 2` | 40,773,022 |
| 5.4 | Per-genotype depth ≥ 5, missing ≤ 20% | VCFtools | `--minDP 5 --max-missing 0.80` | 6,597,948 |
| 5.5 | Sample selection (40 individuals) | VCFtools | `--keep samples_40.txt` | 6,597,948 |
| 5.6 | Missing ≤ 10%, max depth (Meynert) | VCFtools | `--max-missing 0.90 --maxDP 708` | 5,250,175 |

### 6. Dataset-specific filtering

#### Dataset A — Population structure (PCA, DAPC, relatedness)

```bash
# MAF filter
vcftools --vcf common_filtered.vcf --maf 0.03 --recode --out datasetA_maf

# LD pruning
plink --vcf datasetA_maf.recode.vcf --indep-pairwise 100 50 0.1 \
  --allow-extra-chr --out datasetA_ld
plink --vcf datasetA_maf.recode.vcf --extract datasetA_ld.prune.in \
  --recode vcf --allow-extra-chr --out datasetA_pruned
```

**Result: 3,406 LD-independent biallelic SNPs**

#### Dataset B — Effective population size (currentNe2) and ROH

```bash
# No MAF filter (needed for Ne estimation)
# Strict biallelic, missingness ≤ 10%
bcftools view -m2 -M2 -v snps common_filtered.vcf > datasetB.vcf
```

**Result: 231,969 biallelic SNPs** (per cohort: 68,595 polymorphic in 2005; 62,911 in 2023)

#### Dataset C — Genome-wide diversity (pixy, Stacks populations)

```bash
# All-sites VCF (variants + invariants), 0% missing per site
vcftools --vcf common_filtered.vcf --max-missing 1.0 --recode --out datasetC

# pixy for unbiased π
pixy --stats pi --vcf datasetC.recode.vcf.gz \
  --populations popfile.txt --window_size 10000 --output_prefix pixy_out

# Stacks populations for Ho, He
populations -V datasetC.recode.vcf -O stacks_out -M popmap.txt
```

**Result: 663,989 sites** (38,370 variant + 625,619 invariant)

## Dataset summary

| Dataset | SNPs/Sites | MAF | Missing | LD pruned | Used for |
|---------|-----------|-----|---------|-----------|----------|
| A | 3,406 | ≥ 0.03 | ≤ 20% | Yes (r² < 0.1) | PCA, DAPC, relatedness, PERMANOVA |
| B | 231,969 | None | ≤ 10% | No | currentNe2 (LD-based Ne), ROH |
| C | 663,989 | None | 0% | No | pixy (π, dxy, Fst), Stacks (Ho, He) |

## Empirical summary statistics (Dataset C, all-sites)

| Metric | 2005 cohort | 2023 cohort |
|--------|-------------|-------------|
| π | 2.821 × 10⁻³ | 2.686 × 10⁻³ |
| Ho | 0.0494 | 0.0464 |
| He | 0.0476 | 0.0453 |
| Ne (currentNe2, Dataset B) | 1,006 | 568 |

## References

- Catchen, J. et al. (2013). Stacks. *Mol. Ecol.* 22, 3124–3140.
- Garrison, E. & Marth, G. (2012). FreeBayes. arXiv:1207.3907.
- Korunes, K. L. & Samuk, K. (2021). pixy. *Mol. Ecol. Resour.* 21, 1359–1368.
- Li, H. (2013). BWA-MEM. arXiv:1303.3997.
- Rochette, N. C. et al. (2019). Stacks 2. *Mol. Ecol.* 28, 4737–4754.
- Santiago, E. et al. (2024). currentNe2. *Mol. Ecol. Resour.* 24, e13877.
