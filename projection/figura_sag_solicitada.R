#!/usr/bin/env Rscript
suppressMessages({ library(ggplot2); library(dplyr); library(tidyr); library(patchwork) })
select <- dplyr::select; filter <- dplyr::filter
mutate <- dplyr::mutate; summarise <- dplyr::summarise

OI <- c(blue="#0072B2", orange="#E69F00", green="#009E73")
tiempos <- c("2005","2023","+18 yr","+36 yr","+54 yr","+72 yr","+90 yr","+108 yr")
sufijos <- c("2005","2023","18","36","54","72","90","108")
etq <- setNames(tiempos, sufijos)

datos <- read.table("resultados_sag_sol.txt", header=TRUE, sep="\t")
a_largo <- function(df, met) {
  cols <- paste0(met, "_", sufijos)
  df %>% select(all_of(cols)) %>%
    pivot_longer(all_of(cols), names_to="t", values_to="v") %>%
    mutate(tiempo=factor(etq[sub(paste0(met,"_"), "", t)], levels=tiempos),
           x=as.integer(tiempo), metrica=met)
}
largo <- bind_rows(a_largo(datos,"Pi"), a_largo(datos,"He"), a_largo(datos,"Ho"))
resumen <- largo %>% group_by(metrica, tiempo, x) %>%
  summarise(media=mean(v), sem=sd(v)/sqrt(n()), .groups="drop") %>%
  mutate(lo=media-sem, hi=media+sem)

tema <- theme_classic(base_size=11) +
  theme(plot.title=element_text(face="bold"),
        axis.text.x=element_text(angle=35, hjust=1, size=8),
        panel.grid.major.y=element_line(color="grey92"))

# Panel A: Pi
pA <- resumen %>% filter(metrica=="Pi") %>%
  mutate(media=media*1e5, lo=lo*1e5, hi=hi*1e5) %>%
  ggplot(aes(x, media)) +
  annotate("rect", xmin=0.5, xmax=2, ymin=-Inf, ymax=Inf, fill="grey85", alpha=0.4) +
  annotate("text", x=1.25, y=Inf, label="Observed", size=3, color="grey40", vjust=1.5) +
  annotate("text", x=5, y=Inf, label="Projection", size=3, color="grey40", vjust=1.5) +
  geom_vline(xintercept=2, linetype="dotted", color="grey50") +
  geom_ribbon(aes(ymin=lo, ymax=hi), fill=OI["blue"], alpha=0.3) +
  geom_line(color=OI["blue"], linewidth=1) +
  geom_point(color=OI["blue"], size=2) +
  scale_x_continuous(breaks=1:8, labels=tiempos) +
  scale_y_continuous(limits=c(0, NA), expand=expansion(mult=c(0, 0.1))) +
  labs(title="A . Nucleotide diversity", x=NULL, y=expression(pi%*%10^-5)) + tema

# Panel B: He + Ho con etiquetas directas
het <- resumen %>% filter(metrica %in% c("He","Ho")) %>%
  mutate(metrica=factor(metrica, levels=c("He","Ho")))
ult <- het %>% filter(x==8)
pB <- ggplot(het, aes(x, media, color=metrica, fill=metrica, group=metrica)) +
  annotate("rect", xmin=0.5, xmax=2, ymin=-Inf, ymax=Inf, fill="grey85", alpha=0.4) +
  geom_vline(xintercept=2, linetype="dotted", color="grey50") +
  geom_ribbon(aes(ymin=lo, ymax=hi), alpha=0.3, color=NA) +
  geom_line(linewidth=1) +
  geom_point(size=2) +
  geom_text(data=ult, aes(label=metrica, color=metrica),
            x=8.15, hjust=0, size=4, fontface="bold", show.legend=FALSE) +
  scale_color_manual(values=c(He=unname(OI["orange"]), Ho=unname(OI["green"]))) +
  scale_fill_manual(values=c(He=unname(OI["orange"]), Ho=unname(OI["green"]))) +
  scale_x_continuous(breaks=1:8, labels=tiempos, limits=c(0.5, 8.7)) +
  scale_y_continuous(limits=c(0, NA), expand=expansion(mult=c(0, 0.1))) +
  labs(title="B . Heterozygosity", x=NULL, y="Heterozygosity") +
  tema + theme(legend.position="none")

figura <- pA / pB +
  plot_annotation(
    title="Projected genetic diversity under quota",
    subtitle=expression(paste(italic(""),
              "")),
    caption="Harvest scenario: 4.2%/year (SAG-authorized quota for Timaukel).",
    theme=theme(plot.title=element_text(face="bold", size=13),
                plot.subtitle=element_text(size=9.5, color="grey40")))

ggsave("Fig_SAG_solicitada.pdf", figura, width=8, height=8, device=cairo_pdf)
ggsave("Fig_SAG_solicitada.png", figura, width=8, height=8, dpi=300)
cat("Figura guardada\n")
