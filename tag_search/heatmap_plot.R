source("http://bioconductor.org/biocLite.R")
biocLite()
biocLite(c("edgeR","getopt", "MASS"))
library(FactoMineR)


table_all <- read.delim("~/git/csv_tradis/S8_cpm_0.001_1.tsv", sep = '\t', dec=".", row.names=1)
table_hc  <- read.delim("~/git/csv_tradis/HC_cpm_0.001_1.tsv", sep = '\t', dec=".", row.names=1)
table_lc  <- read.delim("~/git/csv_tradis/LC_cpm_0.001_1.tsv", sep = '\t', dec=".", row.names=1)


dALL <- dist(t(table_all))
dHC  <- dist(t(table_hc))
dLC  <- dist(t(table_lc))

plot(hclust(dALL), main = 'Dendrogram, all samples')
plot(hclust(dHC), main = 'Dendrogram, high conc samples')
plot(hclust(dLC), main = 'Dendrogram, low conc samples')


heatmap(as.matrix(table_all))
heatmap(as.matrix(table_hc))
heatmap(as.matrix(table_lc))


res <- PCA(t(table), quali.sup = 1)
plot(res, choix="ind",habillage=1)
dimdesc(res.pca, axes = 1:2)


table_all <- read.delim("~/git/csv_tradis/001_diamond.txt", sep = '\t', dec=".", row.names=1)
View(table_all)
d  <- dist(t(table_all))
plot(hclust(d), main = 'Dendrogram, all samples')
heatmap.2(as.matrix(table_all))


if (!require("gplots")) {
  install.packages("gplots", dependencies = TRUE)
  library(gplots)
}
if (!require("RColorBrewer")) {
  install.packages("RColorBrewer", dependencies = TRUE)
  library(RColorBrewer)
}

data <- table
data <- read.csv("~/git/filteredcsv/demo.csv", comment.char="#")

rnames <- data[,1]                            # assign labels in column 1 to "rnames"
mat_data <- data.matrix(data[,2:ncol(data)])  # transform column 2-5 into a matrix
rownames(mat_data) <- rnames                  # assign row names

my_palette <- colorRampPalette(c("red", "yellow", "green"))(n = 299)

col_breaks = c(seq(-1,0,length=1000), # for red
               seq(0,0.8,length=1000),  # for yellow
               seq(0.81,1,length=1000)) # for green

heatmap.2(mat_data,
          cellnote = mat_data,  # same data set for cell labels
          main = "Correlation", # heat map title
          notecol="black",      # change font color of cell labels to black
          density.info="none",  # turns off density plot inside color legend
          trace="none",         # turns off trace lines inside the heat map
         
          col=my_palette,       # use on color palette defined earlier
         
          dendrogram="row",     # only draw a row dendrogram
          Colv="NA")            # turn off column clustering
