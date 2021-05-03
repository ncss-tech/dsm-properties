setwd("D:/DSM_focus_team/PropertiesTeam")
install.packages("RSQLite")
library(RSQLite)
library(scales)

#kssl data
#bring in sqlite db
kssl.sql <- dbConnect(RSQLite::SQLite(),"KSSL-data.sqlite")

dbListTables(kssl.sql)

dbListFields(kssl.sql, "NCSS_Pedon_Taxonomy")

# convert to data frame
kssl<- as.data.frame(dbReadTable(kssl.sql, "NCSS_Pedon_Taxonomy"))
names(kssl)
kssl$peiid <- kssl$pedoniid 
names(kssl)
kssl <- kssl[,66:68]
# add source field
kssl$source <- "kssl"
head(kssl)
kssl <- kssl[, c("peiid", "source")]

kssl <- unique(kssl)

# bring in component pedon linkages
coped <- read.csv("copedon-link-cokey.csv")
names(coped)
# convert to data.frame and add source
coped$source <- "copedLink"

coped <- coped[,c("peiid", "source")]

# one pedon may be linked to many component pedons need to remove multiples
coped <- unique(coped)

# component spatial matching
matchSSURGO <- readRDS("D:/DSM_focus_team/PropertiesTeam/NASIS20_SSURGO20_comp_extract_final/NASIS_all_component_match_ssurgo20.rds")
names(matchSSURGO)
matchSSURGO <- matchSSURGO[,c(1,3)]
names(matchSSURGO)[2] <- "source"
names(matchSSURGO)
levels(as.factor(matchSSURGO$source))

matchSSURGO <- unique(matchSSURGO)

# pedon taxonomy
# bring in NASIS data
load("nasis_sites_20210325.RData")
load("nasis_pedons_20210325.RData")
names(spc)
names(s)
site(spc)

s <- site(spc)
levels(as.factor(s$pedontype))
levels(as.factor(s$pedonpurpose))
levels(as.factor(s$classtype))

names(s)
s.sub <- s[, c("peiid", "pedontype", "pedonpurpose", "classtype")]

s.sub$peiid <- unique(s.sub$peiid)

# total number of observations
nrow(s.sub)
# subset pt, pp, ct contain no nulls


tpc <- subset(s.sub, !is.na(pedontype) & !is.na(pedonpurpose) & !is.na(classtype))
tc <- subset(s.sub, !is.na(pedontype) & is.na(pedonpurpose) & !is.na(classtype))
pc <- subset(s.sub, is.na(pedontype) & !is.na(pedonpurpose) & !is.na(classtype))
c <- subset(s.sub, is.na(pedontype) & is.na(pedonpurpose) & !is.na(classtype))
tp <- subset(s.sub, !is.na(pedontype) & !is.na(pedonpurpose) & is.na(classtype))
t <- subset(s.sub, !is.na(pedontype) & is.na(pedonpurpose) & is.na(classtype))
p <- subset(s.sub, is.na(pedontype) & !is.na(pedonpurpose) & is.na(classtype))
null <- subset(s.sub, is.na(pedontype) & is.na(pedonpurpose) & is.na(classtype))

nrow(s.sub)
nrow(tpc)+nrow(pc)+nrow(tc)+nrow(null)+nrow(t)+nrow(p)+nrow(c)+nrow(tp)

tpc$source <- "TPC"
tc$source <- "tc"
pc$source <-"pc"
c$source <- "c"
tp$source <- "tp"
t$source <- "t"
p$source <- "p"
null$source <- "null"


# all nasis data

nasis_pedons <- rbind(tpc, tc, pc, c, tp, t, p, null)

names(nasis_pedons)
nasis_pedons <- nasis_pedons[,c("peiid", "source")]
names(nasis_pedons)

#subset to remove peiid from nasis pedons that exist in kssl, match ssurgo, coped
nrow(nasis_pedons)
nasis.sub <- nasis_pedons[!(nasis_pedons$peiid %in% kssl$peiid),] # remove kssl pedons
nrow(nasis.sub)
nasis.sub <- nasis.sub[!(nasis.sub$peiid %in% coped$peiid),] # remove coped pedons
nrow(nasis.sub)
nasis.sub <- nasis.sub[!(nasis.sub$peiid %in% matchSSURGO$peiid),] # remove matchSSURGO pedons
nrow(nasis.sub)

# subset to remove kssl and coped from match ssurgo
matchSSURGO.sub <- matchSSURGO[!(matchSSURGO$peiid %in% kssl$peiid),] # remove kssl pedons
matchSSURGO.sub <- matchSSURGO[!(matchSSURGO$peiid %in% coped$peiid),] # remove coped pedons

# subset to remove kssl from coped
coped.sub <- coped[!(coped$peiid %in% kssl$peiid),] # remove kssl pedons


kssl.sub <- kssl[, c("peiid", "source")]


wt.pedon.quality <- rbind(kssl.sub, coped.sub, matchSSURGO.sub, nasis.sub)
nrow(wt.pedon.quality)

levels(as.factor(wt.pedon.quality$source))

# assign weights to classes

wt.pedon.quality$wt[wt.pedon.quality$source == "kssl"] <- 13
wt.pedon.quality$wt[wt.pedon.quality$source == "copedLink"] <- 12
wt.pedon.quality$wt[wt.pedon.quality$source == "direct"] <- 11
wt.pedon.quality$wt[wt.pedon.quality$source == "home"] <- 10
wt.pedon.quality$wt[wt.pedon.quality$source == "adjacent"] <- 9
wt.pedon.quality$wt[wt.pedon.quality$source == "TPC"] <- 08
wt.pedon.quality$wt[wt.pedon.quality$source == "tc"] <- 7
wt.pedon.quality$wt[wt.pedon.quality$source == "pc"] <- 6
wt.pedon.quality$wt[wt.pedon.quality$source == "c"] <- 5
wt.pedon.quality$wt[wt.pedon.quality$source == "tp"] <- 4
wt.pedon.quality$wt[wt.pedon.quality$source == "p"] <- 3
wt.pedon.quality$wt[wt.pedon.quality$source == "t"] <- 2
wt.pedon.quality$wt[wt.pedon.quality$source == "null"] <- 1


#rescale from 1 to 13 to 0 to 1
wt.pedon.quality$wt <- rescale(wt.pedon.quality$wt)


saveRDS(wt.pedon.quality, "pedonquality_weighting.RDS")

