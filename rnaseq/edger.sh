# Mock script

set -euxo pipefail



for EXP in 1815 2272;
do
	for GENO in WT TG;
	do
		./subsample_matrix.pl -m ${EXP}.metadata -t ${EXP}.tsv -c Genotype=$GENO
	done

        for GENO in T0 T1;
        do
                ./subsample_matrix.pl -m ${EXP}.metadata -t ${EXP}.tsv -c Time=$GENO
        done


	./edgeR_analysis.pl -m ${EXP}.metadata -t  ${EXP}.tsv -o full_edgeR_$EXP

	for i in ${EXP}*-*;
	do
		echo $i;
		./edgeR_analysis.pl -m ${EXP}.metadata -t $i -o edgeR_$(basename ${i/.tsv/}) -d -v; 
	done
done
