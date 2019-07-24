#LOAD, CLEAN UP AND PROCESS DATA#
##########################################################################################################################

library(httr)
library(RCurl)
library(dplyr)
library(magrittr)
library(ggplot2)
library(ggpubr)
library(lattice)
library(ggeffects)
library(multcomp)


#CHUNK REDUNDANT AFTER FACS cell population conversion, moved there
# ANTfileUrl <- "https://raw.githubusercontent.com/derele/Eimeria_Lab/master/data/3_recordingTables/E7_112018_Eim_CD40L_assays_anteriorMLN.csv"
# 
# ANT <- read.csv(text=getURL(ANTfileUrl))
# 
# POSfileUrl <- "https://raw.githubusercontent.com/derele/Eimeria_Lab/master/data/3_recordingTables/E7_112018_Eim_CD40L_assays_posteriorMLN.csv"
# 
# POS <- read.csv(text=getURL(POSfileUrl))
# 
# #name columns properly (check before using, csv reads different now and then#
# names(ANT) <- c("Sample","ThCD4p","TcCD8p","Th1IFNgp_in_CD4p","Th17IL17Ap_in_CD4p",
#                 "Tc1IFNgp_in_CD8p","Treg_Foxp3_in_CD4p","Dividing_Ki67p_in_Foxp3p",
#                 "RORgtp_in_Foxp3p","Th1Tbetp_in_CD4pFoxp3n","Dividing_Ki67p_in_Tbetp",
#                 "Th17RORgp_in_CD4pFoxp3n","Dividing_Ki67p_in_RORgtp")
# names(POS) <- c("Sample","ThCD4p","TcCD8p","Th1IFNgp_in_CD4p","Th17IL17Ap_in_CD4p",
#                 "Tc1IFNgp_in_CD8p","Treg_Foxp3_in_CD4p","Dividing_Ki67p_in_Foxp3p",
#                 "RORgtp_in_Foxp3p","Th1Tbetp_in_CD4pFoxp3n","Dividing_Ki67p_in_Tbetp",
#                 "Th17RORgp_in_CD4pFoxp3n","Dividing_Ki67p_in_RORgtp")
# 
# #set columns to numbers
# 
# 
# CELLS <- rbind(ANT, POS)
# 
# #extract Mouse_ID from that mess and paste in "LM02" to standardize with our data structure
# CELLS$EH_ID <- gsub("\\d+: (Anterior|Posterior) LN_(\\d{2})_\\d{3}.fcs", "LM02\\2", CELLS$Sample)
# CELLS$Position <- gsub("\\d+: (Anterior|Posterior) LN_(\\d{2})_\\d{3}.fcs", "\\1", CELLS$Sample)

#read in cell counts (FACS) data
cell.countsURL <- "https://raw.githubusercontent.com/derele/Eimeria_Lab/master/data/3_recordingTables/E7_112018_Eim_FACS_cell_counts_processed.csv"
cell.counts <- read.csv(text = getURL(cell.countsURL))

#remove mouse 293 as it was mixed both posterior and anterior + remove everpresent X column
cell.counts$X = NULL
cell.counts <- cell.counts[!cell.counts$EH_ID%in%"LM0293",] 

#####################################################################################################################################
#introduce parasitological data
paraURL <- "https://raw.githubusercontent.com/derele/Eimeria_Lab/master/data/3_recordingTables/E7_112018_Eim_complete.csv"
E7 <- read.csv(text=getURL(paraURL))
E7$X = NULL
#merge FACS with para data
E7 <- merge(E7[E7$dpi%in%8,], cell.counts, by = "EH_ID")
#include combined infection history
E7$infHistory <- E7$primary:E7$challenge

##select cell population names (now using .cells to calculate with actual cell populations)
facs.measure.cols <- c("ThCD4p", "TcCD8p", "Th1IFNgp_in_CD4p", "Th17IL17Ap_in_CD4p", 
                       "Tc1IFNgp_in_CD8p", "Treg_Foxp3_in_CD4p", "Dividing_Ki67p_in_Foxp3p", 
                       "RORgtp_in_Foxp3p", "ThCD4p_Foxp3n", "Th1Tbetp_in_CD4pFoxp3n", "Dividing_Ki67p_in_Tbetp", 
                       "Th17RORgp_in_CD4pFoxp3n", "Dividing_Ki67p_in_RORgtp")

#test for normality
#if(!require(devtools)) install.packages("devtools")
#devtools::install_github("kassambara/ggpubr") use for every cell line
ggdensity(E7$ThCD4p.cells, 
          main = "Density plot of ThCD4p cells",
          xlab = "population counts")

## tabulate  medians for different infection histories and anterior vs posterior
## create list of cell populations summaries infection strains
cell.medians <- lapply(facs.measure.cols, function (x){
  tapply(E7[, x], list(E7$infHistory, as.factor(E7$Position)), median)
})
names(cell.medians) <- facs.measure.cols
cell.medians

#cell means of all mice across infection histories (maybe trim 5% for outliers witth mean( , trim = .05)?)
with(E7, mean(ThCD4p.cells[infHistory == "E64:E64"]))
with(E7, mean(ThCD4p.cells[infHistory == "E64:E88"]))
with(E7, mean(ThCD4p.cells[infHistory == "E88:E64"]))
with(E7, mean(ThCD4p.cells[infHistory == "E88:E88"]))

cell.means <- lapply(facs.measure.cols, function (x){
  tapply(E7[, x], list(E7$infHistory, as.factor(E7$Position)), mean)
})
names(cell.means) <- facs.measure.cols
cell.means

#check distribution with histogram
histogram(~infHistory | facs.measure.cols, data = E7)
histogram(~Position | facs.measure.cols, data = E7)

## #check distribution infHistory
plotCells.inf <- function (col){
  ggplot(E7, aes(infHistory, get(col))) +
    geom_boxplot() +
    geom_jitter(width=0.2) +
    facet_wrap(~Position) +
    ggtitle(col)
}

facs_boxplots.inf <- lapply(facs.measure.cols, plotCells.inf)
names(facs_boxplots.inf) <-  facs.measure.cols

for(i in seq_along(facs_boxplots.inf)){
  pdf(paste0(names(facs_boxplots.inf)[[i]], ".inf.pdf"))
  plot(facs_boxplots.inf[[i]])
  dev.off()
}

## #check distribution Position
plotCells.position<- function (col){
  ggplot(E7, aes(Position, get(col))) +
    geom_boxplot() +
    geom_jitter(width=0.2) +
    facet_wrap(~infHistory) +
    ggtitle(col)
}

facs_boxplots.position <- lapply(facs.measure.cols, plotCells.position)
names(facs_boxplots.position) <-  facs.measure.cols

for(i in seq_along(facs_boxplots.position)){
  pdf(paste0(names(facs_boxplots.position)[[i]], ".position.pdf"))
  plot(facs_boxplots.position[[i]])
  dev.off()
}

### raw counts are modeled either as poisson or negative binomial in
### either case one could use the overall count (cell_counts) as
### "offset" to specify the "duration of observation" (normally
### offsets are used as a ratio, counto over time). I tried that, but
### then figured out that I know too little about how to interprete
### counts... expecially because the overall cell numbers are varying
### SO MUCH that this changes the results completely!!!

#### model Position

mods.l <- lapply(facs.measure.cols, function (x) {
    glm(get(x) ~ (primary * challenge) + Position,
        data=E7)
})
names(mods.l) <- facs.measure.cols

lapply(mods.l, summary)

for(i in seq_along(facs.measure.cols)){
    eff <- ggpredict(mods.l[[i]], terms=c("primary", "challenge", "Position"))
    plot <-  plot(eff, rawdata=TRUE) +
        scale_y_continuous(paste("percent", facs.measure.cols[[i]])) +
        ggtitle(paste("predicted values of", facs.measure.cols[[i]]))
    pdf(paste0(facs.measure.cols[[i]], ".effects.pdf"))
    print(plot)
    dev.off()
}

## I looked at the CD4 and CD8 INF cells b/c I remembered they were
## "interesting". The pattern we see sofar in these cells is, however
## that they are found _less_ posterior and _less_ in E64 primary. I
## controlled this to be correct correct in basic means and medians...

## Could this mean that E64 infection surpresses these INF producing
## (?) cell types more than E88?!
### |-> this would make sense as the E88 ifections are more severe in terms of tissue damage. This could be explained by a highly 
### stimulated Cytotoxic lymphocite populations (TcCD8+) and killing of infected/stress signalling epithelial cells. Also any shift
### towards higher CD4+ Treg population would explain decrease in Th1CD4+ (inflammatory) and TcCD8+ (killer) cell presence.


## -> Then our prediction would be that it's good for the host to have
## littel of these cell types???

## Let's have a first peek into how different hybrids are to pure mice
## in this respect...

## Model Hybrid status
modsHY.l <- lapply(facs.measure.cols, function (x) {
    glm(get(x) ~ (primary * challenge) + Position + HybridStatus,
        data=E7)
})
names(modsHY.l) <- facs.measure.cols

lapply(modsHY.l, summary)


## And WOW (I reall wrote the above A PRIORY, otherwise... mayor
## fishing excursion ;-)...), but Tc1IFNgp_in_CD8p are lower in
## HYBRIDS look at THIS!!
summary(modsHY.l[["Tc1IFNgp_in_CD8p"]])

WOW <- ggpredict(modsHY.l[["Tc1IFNgp_in_CD8p"]],
                 terms=c("primary", "challenge", "HybridStatus"))

summary(modsHY.l[["Tc1IFNgp_in_CD8p"]], )

pdf("WINNER_Tc1IFNgp_in_CD8p.effects.pdf")
plot(WOW)
dev.off()


## Now... I fooled myself a bit to that enthusiasm, as I expected
## "HybridStatusoutbred hybrids" to be ... well ... hybrids. Turns out
## this are the within subspecies outbreds. Let's do some PostHoc
## comparison. 

summary(glht(modsHY.l[["Tc1IFNgp_in_CD8p"]], mcp(HybridStatus="Tukey")))

## nothing too shocking here, just that "outbred hybrids" have a trend
## towards lower cell proportions compared to "inter subsp. hybrids"

## use Emanuel's method to look at other populations (make into function/loop later)

modsHY.l <- lapply(facs.measure.cols, function (x) {
  glm(get(x) ~ (primary * challenge) + Position + HybridStatus,
      data=E7)
})
names(modsHY.l) <- facs.measure.cols

lapply(modsHY.l, summary)


for(i in seq_along(facs.measure.cols)){
  hyb <- ggpredict(modsHY.l[[i]], terms=c("primary", "challenge", "HybridStatus"))
  plot <-  plot(hyb, rawdata=TRUE) +
    scale_y_continuous(paste("percent", facs.measure.cols[[i]])) +
    ggtitle(paste("predicted values of", facs.measure.cols[[i]]))
  pdf(paste0(facs.measure.cols[[i]], ".predict.pdf"))
  print(plot)
  dev.off()
}

# Run Tukey for all (fix = all values are the same)
#predict.tukeys <- lapply(modsHY.l, function (x){
#problem is with "x" summary(glht(modsHY.l[[x]], mcp(HybridStatus="Tukey")))
#})

### Temporarily run Tukey on hybrid status independently by naming facs.name.cols
ThCD4p.Tukey <- summary(glht(modsHY.l[["ThCD4p"]], mcp(HybridStatus="Tukey"))) 
TcCD8p.Tukey <- summary(glht(modsHY.l[["TcCD8p"]], mcp(HybridStatus="Tukey")))
Th1IFNgp_in_CD4p.Tukey <- summary(glht(modsHY.l[["Th1IFNgp_in_CD4p"]], mcp(HybridStatus="Tukey")))
Th17IL17Ap_in_CD4p.Tukey <- summary(glht(modsHY.l[["Th17IL17Ap_in_CD4p"]], mcp(HybridStatus="Tukey")))
Tc1IFNgp_in_CD8p.Tukey <- summary(glht(modsHY.l[["Tc1IFNgp_in_CD8p"]], mcp(HybridStatus="Tukey"))) #"outbred hybrids" have a trend towards lower cell proportions compared to "inter subsp. hybrids"
Treg_Foxp3_in_CD4p.Tukey <- summary(glht(modsHY.l[["Treg_Foxp3_in_CD4p"]], mcp(HybridStatus="Tukey")))
Dividing_Ki67p_in_Foxp3p.Tukey <- summary(glht(modsHY.l[["Dividing_Ki67p_in_Foxp3p"]], mcp(HybridStatus="Tukey")))
RORgtp_in_Foxp3p.Tukey <- summary(glht(modsHY.l[["RORgtp_in_Foxp3p"]], mcp(HybridStatus="Tukey")))
ThCD4p_Foxp3n.Tukey <- summary(glht(modsHY.l[["ThCD4p_Foxp3n"]], mcp(HybridStatus="Tukey")))
Th1Tbetp_in_CD4pFoxp3n.Tukey <- summary(glht(modsHY.l[["Th1Tbetp_in_CD4pFoxp3n"]], mcp(HybridStatus="Tukey")))
Dividing_Ki67p_in_Tbetp.Tukey <- summary(glht(modsHY.l[["Dividing_Ki67p_in_Tbetp"]], mcp(HybridStatus="Tukey")))
Th17RORgp_in_CD4pFoxp3n.Tukey <- summary(glht(modsHY.l[["Th17RORgp_in_CD4pFoxp3n"]], mcp(HybridStatus="Tukey")))
Dividing_Ki67p_in_RORgtp.Tukey <- summary(glht(modsHY.l[["Dividing_Ki67p_in_RORgtp"]], mcp(HybridStatus="Tukey")))

old.par <- par(mai=c(1,3,0.3,0.1)) #Makes room on the plot for the group names
plot(ThCD4p.Tukey, main = "ThCD4p Tukey") # hybrids > outbreds, parent = outbreds, parent < hybrid
plot(TcCD8p.Tukey, main = "TcCD8p Tukey") # hybrid > outbred, parent < outbred, parent < hybrid
plot(Th1IFNgp_in_CD4p.Tukey, main = "Th1IFNgp_in_CD4p.Tukey") # hybrid < outbred, parent < outbred, parent > hybrid
plot(Th17IL17Ap_in_CD4p.Tukey, main = "Th17IL17Ap_in_CD4p.Tukey") # hybrid < outbred, parent < outbred, parent < hybrid
plot(Tc1IFNgp_in_CD8p.Tukey, main = "Tc1IFNgp_in_CD8p.Tukey") # hybrid < outbred, parent < outbred, parent > hybrid
plot(Treg_Foxp3_in_CD4p.Tukey, main = "Treg_Foxp3_in_CD4p.Tukey") # hybrid < outbred, parent < outbred, parent < hybrid
plot(Dividing_Ki67p_in_Foxp3p.Tukey, main = "Dividing_Ki67p_in_Foxp3p.Tukey") # all == 
plot(RORgtp_in_Foxp3p.Tukey, main = "RORgtp_in_Foxp3p.Tukey") # hybrid < outbred, parent = outbred, parent > hybrid
plot(ThCD4p_Foxp3n.Tukey, main = "ThCD4p_Foxp3n.Tukey") # hybrid > outbred, parent > outbred, parent = hybrid
plot(Th1Tbetp_in_CD4pFoxp3n.Tukey, main = "Th1Tbetp_in_CD4pFoxp3n.Tukey") # hybrids < outbred, parent = outbreds, parent > hybrids
plot(Dividing_Ki67p_in_Tbetp.Tukey, main = "Dividing_Ki67p_in_Tbetp.Tukey") # hybrids < outbreds, parent = outbreds, parent > hybrids
plot(Th17RORgp_in_CD4pFoxp3n.Tukey, main = "Th17RORgp_in_CD4pFoxp3n.Tukey") # hybrid < outbred, parent = outbred, parent > hybrid
plot(Dividing_Ki67p_in_RORgtp.Tukey, main = "Dividing_Ki67p_in_RORgtp.Tukey") # hybrid < outbred, parent = outbred, parent > hybrid