#!/bin/bash
#Versione
VERSION='1.03'

#changelog
#1.03 Renamed BoxPlot1, BoxPlot2 e Jaknifed folders to actual names
. /etc/profile.d/modules.sh
module load qiime

echo MICROBITTER SEQUEL $VERSION
echo "Launch from the directory to analyze (should contain ./OTUs/filtered.biom)"
echo "or give directory as first parameter."
BACK=0
if [ -d "$1" ]
then
	cd "$1"
	BACK=1
fi
if [ -s "reads.fna" ] && [ -s "mapping_auto.tsv" ] && [ -s "OTUs/filtered.biom" ]
then
	echo " [CHECK OK] Input dir checked: reads, mapping file and filtered.biom are present"
else
	echo mapping_auto.tsv and/or reads.fna not found
	exit 11
fi

if [ -s "SummarizedTaxa_L7/filtered_L7.txt" ]
then
	echo " [ERROR 22] Finished or aborted calculations found. Remove before starting"
	exit 22
fi

touch microbitter_$VERSION.run

biom summarize-table -i OTUs/filtered.biom -o OTUs/table_summary.txt
let MINREADS=`cat OTUs/table_summary.txt | grep "Min:"|cut -f2 -d":"  |cut -f 1 -d.|sed 's/ //g'`

make_otu_heatmap.py -i OTUs/filtered.biom  -o Heatmap.pdf
#WAS:summarize_taxa.py -i OTUs/filtered.biom -o SummarizedTaxa_L7 -L 2,3,4,5,6,7
plot_taxa_summary.py -i SummarizedTaxa_L7/filtered_L7.txt -l species -c pie,bar,area -o Charts_Species
plot_taxa_summary.py -i SummarizedTaxa_L7/filtered_L6.txt -l species -c pie,bar,area -o Charts_Genus
summarize_taxa_through_plots.py -i OTUs/filtered.biom -o Taxa_Summary -m mapping_auto.tsv 
biom convert -i OTUs/filtered.biom -o OTUs/filtered.tsv --to-tsv
biom summarize-table -i OTUs/filtered.biom -o OTUs/filtered_table_summary.txt
filter_tree.py -i OTUs/97_otus.tree -t OTUs/filtered.tsv -o OTUs/filtered_pruned.tree


alpha_rarefaction.py -i OTUs/filtered.biom -o AlphaRarefaction/ -t OTUs/filtered_pruned.tree -m mapping_auto.tsv 

beta_diversity_through_plots.py -i OTUs/filtered.biom -o BetaDiversity/ -t OTUs/filtered_pruned.tree -m  mapping_auto.tsv  -e $MINREADS
alpha_diversity.py -i BetaDiversity/filtered_even$MINREADS.biom -m observed_species,PD_whole_tree,chao1,goods_coverage,shannon,simpson,simpson_e -o AlphaRarefaction/adiv_values.txt -t OTUs/filtered_pruned.tree

#Now moved after beta_Div:
summarize_taxa.py -i OTUs/filtered.biom -o SummarizedTaxa_L7 -L 2,3,4,5,6,7

make_distance_boxplots.py -d BetaDiversity/unweighted_unifrac_dm.txt -m mapping_auto.tsv -f "Treatment" -o Boxplot_Unweighted -g png
make_distance_boxplots.py -d BetaDiversity/weighted_unifrac_dm.txt -m mapping_auto.tsv -f "Treatment" -o Boxplot_Weighted -g png
jackknifed_beta_diversity.py -i OTUs/filtered.biom -o JackknifedBetaDiversity -e 100 -m mapping_auto.tsv -t  OTUs/filtered_pruned.tree  -e $MINREADS

if [ "$BACK" -eq 1 ]
then
	cd -
fi
