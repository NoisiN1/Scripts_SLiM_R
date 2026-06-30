#!/usr/bin/env Rscript
suppressMessages({ library(ggplot2); library(dplyr); library(patchwork) })
select <- dplyr::select

OI_blue <- "#0072B2"; OI_orange <- "#E69F00"; OI_grey <- "grey60"

# Leer posteriors (tolerance 1%)
post_N <- read.csv("ABC_WF_posterior_N.csv")
post_H <- read.csv("ABC_WF_posterior_H.csv")

# Priors uniformes
prior_N <- data.frame(N = runif(50000, 300, 2000))
prior_H <- data.frame(H = runif(50000, 0.05, 0.40))

med_N <- median(post_N$N)
med_H <- median(post_H$H)

tema <- theme_classic(base_size=11) +
  theme(plot.title=element_text(face="bold"),
        legend.position="bottom", legend.title=element_blank(),
        legend.box="horizontal",
        panel.grid.major.y=element_line(color="grey92"))

pA <- ggplot() +
  geom_density(data=prior_N, aes(N, after_stat(density), color="Prior", fill="Prior"), alpha=0.2, linewidth=0.8) +
  geom_density(data=post_N, aes(N, after_stat(density), color="Posterior", fill="Posterior"), alpha=0.4, linewidth=1) +
  geom_vline(xintercept=med_N, color=OI_blue, linetype="dashed", linewidth=0.8) +
  annotate("text", x=med_N, y=Inf, label=sprintf("median = %.0f", med_N),
           hjust=-0.1, vjust=1.5, color=OI_blue, size=3.2) +
  scale_color_manual(values=c(Prior=OI_grey, Posterior=OI_blue)) +
  scale_fill_manual(values=c(Prior=OI_grey, Posterior=OI_blue)) +
  scale_x_continuous(limits=c(300, 2000)) +
  guides(color=guide_legend(override.aes=list(fill=NA)), fill="none") + labs(title="A . Effective population size (N)", x="N", y="Density") + tema

pB <- ggplot() +
  geom_density(data=prior_H, aes(H, after_stat(density), color="Prior", fill="Prior"), alpha=0.2, linewidth=0.8) +
  geom_density(data=post_H, aes(H, after_stat(density), color="Posterior", fill="Posterior"), alpha=0.4, linewidth=1) +
  geom_vline(xintercept=med_H, color=OI_orange, linetype="dashed", linewidth=0.8) +
  annotate("text", x=med_H, y=Inf, label=sprintf("median = %.3f", med_H),
           hjust=-0.1, vjust=1.5, color=OI_orange, size=3.2) +
  scale_color_manual(values=c(Prior=OI_grey, Posterior=OI_orange)) +
  scale_fill_manual(values=c(Prior=OI_grey, Posterior=OI_orange)) +
  scale_x_continuous(limits=c(0.05, 0.40)) +
  guides(color=guide_legend(override.aes=list(fill=NA)), fill="none") + labs(title="B . Hunting fraction per generation (H)", x="H", y="Density") + tema

figura <- pA / pB +
  plot_annotation(
    title="Figure S1. Prior vs posterior distributions of ABC parameters",
    subtitle=expression(paste("Russfin guanaco (", italic("Lama guanicoe"),
              ") . tolerance 1% . n = 500 accepted simulations . 50,000 prior draws")),
    theme=theme(plot.title=element_text(face="bold", size=12),
                plot.subtitle=element_text(size=9, color="grey40")))

ggsave("Fig_S1_prior_posterior.pdf", figura, width=7.5, height=8, device=cairo_pdf)
ggsave("Fig_S1_prior_posterior.png", figura, width=7.5, height=8, dpi=300)
cat("Figura S1 guardada.\n")
