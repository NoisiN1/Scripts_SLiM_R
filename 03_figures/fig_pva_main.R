#!/usr/bin/env Rscript
# Fig PVA - Nature E&E style, smooth lines, clean legend

if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2", repos = "http://cran.r-project.org")
if (!requireNamespace("cowplot", quietly = TRUE)) install.packages("cowplot", repos = "http://cran.r-project.org")
suppressPackageStartupMessages({ library(ggplot2); library(cowplot) })

setwd("~/part3/6.russfin/simulaciones/abc/")

# --- EMPIRICOS Dataset C ---
emp <- data.frame(
  year = c(2005, 2023),
  He = c(0.0476, 0.0453),
  Ho = c(0.0494, 0.0464),
  Pi = c(2.821e-3, 2.686e-3)
)

# --- Simulados H=actual ---
d_all <- NULL
for (M in c(0, 1, 5)) {
  d <- read.table(sprintf("pva_out_final/pva_actual_m%s.txt", M), header=FALSE, sep="\t",
    col.names=c("scen","rep","K","H_hist","H_fut","M_fut","gen_rel","Nc","Nm","Nt","Ne","He","Ho","Pi"))
  d$M_tag <- M
  d_all <- rbind(d_all, d)
}

d_all$M_label <- factor(d_all$M_tag, levels=c(0,1,5),
  labels=c("Closed (m = 0)","Low (m = 0.01)","High (m = 0.05)"))
d_all$year <- 2023 + d_all$gen_rel * 4.5

stats <- aggregate(cbind(He, Ho, Pi) ~ gen_rel + year + M_label + M_tag, data=d_all, FUN=mean)

for (m in unique(stats$M_tag)) {
  idx <- stats$M_tag == m
  stats$He_anc[idx] <- emp$He[2] * stats$He[idx] / stats$He[idx & stats$gen_rel==0]
  stats$Ho_anc[idx] <- emp$Ho[2] * stats$Ho[idx] / stats$Ho[idx & stats$gen_rel==0]
  stats$Pi_anc[idx] <- emp$Pi[2] * stats$Pi[idx] / stats$Pi[idx & stats$gen_rel==0]
}

iqr <- aggregate(cbind(He, Ho, Pi) ~ gen_rel + year + M_label + M_tag, data=d_all,
  FUN=function(x) c(lo=quantile(x, 0.25), hi=quantile(x, 0.75)))

s <- merge(stats, data.frame(gen_rel=iqr$gen_rel, M_tag=iqr$M_tag,
  He_lo_r=iqr$He[,"lo.25%"], He_hi_r=iqr$He[,"hi.75%"],
  Ho_lo_r=iqr$Ho[,"lo.25%"], Ho_hi_r=iqr$Ho[,"hi.75%"],
  Pi_lo_r=iqr$Pi[,"lo.25%"], Pi_hi_r=iqr$Pi[,"hi.75%"]))

for (m in unique(s$M_tag)) {
  idx <- s$M_tag == m
  bHe <- stats$He[stats$M_tag==m & stats$gen_rel==0]
  bHo <- stats$Ho[stats$M_tag==m & stats$gen_rel==0]
  bPi <- stats$Pi[stats$M_tag==m & stats$gen_rel==0]
  s$He_lo[idx] <- emp$He[2] * s$He_lo_r[idx] / bHe
  s$He_hi[idx] <- emp$He[2] * s$He_hi_r[idx] / bHe
  s$Ho_lo[idx] <- emp$Ho[2] * s$Ho_lo_r[idx] / bHo
  s$Ho_hi[idx] <- emp$Ho[2] * s$Ho_hi_r[idx] / bHo
  s$Pi_lo[idx] <- emp$Pi[2] * s$Pi_lo_r[idx] / bPi
  s$Pi_hi[idx] <- emp$Pi[2] * s$Pi_hi_r[idx] / bPi
}

s_proj <- s[s$gen_rel >= 0, ]

# --- Loess smoothing para lineas suaves (atenua dips transitorios) ---
smooth_metric <- function(df, xcol, ycol, group_col, n=200, span_val=0.45) {
  out <- NULL
  for (g in unique(df[[group_col]])) {
    sub <- df[df[[group_col]] == g, ]
    sub <- sub[order(sub[[xcol]]), ]
    if (nrow(sub) < 4) { out <- rbind(out, sub); next }
    lo <- loess(as.formula(paste(ycol, "~", xcol)), data=sub, span=span_val)
    xnew <- seq(min(sub[[xcol]]), max(sub[[xcol]]), length.out=n)
    newdf <- data.frame(xnew); names(newdf) <- xcol
    ynew <- predict(lo, newdata=newdf)
    names(ynew) <- NULL
    tmp <- data.frame(x=xnew, y=ynew, grp=g)
    names(tmp) <- c(xcol, ycol, group_col)
    out <- rbind(out, tmp)
  }
  out[[group_col]] <- factor(out[[group_col]], levels=levels(df[[group_col]]))
  out
}

# --- Config ---
gen_breaks <- c(-4, 0, 4, 8, 12, 16, 20, 24)
year_breaks <- 2023 + gen_breaks * 4.5
x_labels <- c("2005","2023","+18 yr","+36 yr","+54 yr","+72 yr","+90 yr","+108 yr")

col_closed <- "#2166ac"
col_low    <- "#ef8a62"
col_high   <- "#b2182b"
cols <- c("Closed (m = 0)"=col_closed, "Low (m = 0.01)"=col_low, "High (m = 0.05)"=col_high)

theme_nee <- function() {
  theme_classic(base_size=9, base_family="sans") +
  theme(
    axis.line = element_line(linewidth=0.35, colour="black"),
    axis.ticks = element_line(linewidth=0.25, colour="black"),
    axis.title = element_text(size=9),
    axis.text = element_text(size=7.5, colour="black"),
    axis.text.x = element_text(angle=35, hjust=1, vjust=1),
    plot.title = element_text(size=9.5, face="bold", hjust=0, margin=margin(0,0,3,0)),
    legend.position = "none",
    plot.margin = margin(3,6,3,3)
  )
}

make_panel <- function(emp_col, sim_mean, sim_lo, sim_hi, ylab, panel_title, sf=1) {
  # Compute spline BEFORE ggplot
  sm <- do.call(rbind, lapply(levels(s_proj$M_label), function(g) {
    sub <- s_proj[s_proj$M_label == g, ]
    sub <- sub[order(sub$year), ]
    if (nrow(sub) < 4) return(data.frame(year=sub$year, val=sub[[sim_mean]], M_label=sub$M_label))
    sp <- spline(sub$year, sub[[sim_mean]], n=200)
    data.frame(year=sp$x, val=sp$y, M_label=g)
  }))
  sm$M_label <- factor(sm$M_label, levels=levels(s_proj$M_label))

  ggplot() +
    annotate("rect", xmin=min(year_breaks)-8, xmax=2023, ymin=-Inf, ymax=Inf, fill="grey94") +
    geom_vline(xintercept=2023, linetype="dashed", colour="grey75", linewidth=0.25) +
    geom_ribbon(data=s_proj, aes(x=year, ymin=.data[[sim_lo]]*sf, ymax=.data[[sim_hi]]*sf, fill=M_label), alpha=0.12) +
    geom_line(data=sm, aes(x=year, y=val*sf, colour=M_label), linewidth=0.7) +
    geom_line(data=emp, aes(x=year, y=.data[[emp_col]]*sf), colour="black", linewidth=0.6) +
    geom_point(data=emp, aes(x=year, y=.data[[emp_col]]*sf), colour="black", size=2, shape=16) +
    scale_colour_manual(values=cols) + scale_fill_manual(values=cols) +
    scale_x_continuous(breaks=year_breaks, labels=x_labels, expand=expansion(mult=c(0.02,0.02))) +
    scale_y_continuous(expand=expansion(mult=c(0,0.05))) +
    expand_limits(y=0) +
    labs(title=panel_title, y=ylab, x=NULL) +
    theme_nee()
}

pA <- make_panel("Pi","Pi_anc","Pi_lo","Pi_hi",
  expression(pi~(x10^{-3})),
  expression(bold("a")~~"Nucleotide diversity"), sf=1e3)

pB <- make_panel("Ho","Ho_anc","Ho_lo","Ho_hi",
  expression(italic(H)[o]),
  expression(bold("b")~~"Observed heterozygosity"), sf=1)

pC <- make_panel("He","He_anc","He_lo","He_hi",
  expression(italic(H)[e]),
  expression(bold("c")~~"Expected heterozygosity"), sf=1)

# --- Legend ---
leg_df <- data.frame(
  x = rep(c(1,2), 3),
  y = rep(c(1,2), 3),
  Migration = factor(rep(c("Closed (m = 0)","Low connectivity (m = 0.01)","High connectivity (m = 0.05)"), each=2),
    levels=c("Closed (m = 0)","Low connectivity (m = 0.01)","High connectivity (m = 0.05)")))

p_leg <- ggplot(leg_df, aes(x, y, colour=Migration)) +
  geom_line(linewidth=0.8) +
  scale_colour_manual(values=c(col_closed, col_low, col_high), name=NULL) +
  guides(colour=guide_legend(nrow=1)) +
  theme_void(base_size=8) +
  theme(legend.position="bottom",
        legend.text=element_text(size=7.5, margin=margin(0,8,0,0)),
        legend.key.width=unit(0.9,"cm"),
        legend.key.height=unit(0.25,"cm"),
        legend.margin=margin(0,0,0,0))
legend <- get_legend(p_leg)

# Caption
cap <- ggdraw() +
  draw_label("Harvest: 4.2%/year (SAG quota). Black: empirical (Dataset C, all-sites). Bands: IQR.",
             size=7, fontface="italic", colour="grey40", x=0.5, hjust=0.5)

# --- Compose ---
panels <- plot_grid(pA, pB, pC, ncol=1, align="v", rel_heights=c(1,1,1))
fig <- plot_grid(panels, legend, cap, ncol=1, rel_heights=c(1, 0.035, 0.03))

ggsave("Fig_PVA_main.png", fig, width=5.5, height=9.5, dpi=300)
ggsave("Fig_PVA_main.pdf", fig, width=5.5, height=9.5)
cat("Guardado: Fig_PVA_main.png/.pdf\n")
