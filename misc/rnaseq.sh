#!/bin/bash

set -euo pipefail

REF=/db/mm/dna/Mus_musculus.GRCm38.dna.toplevel.fa
DB=/db/mm/dna/Mm_hisat2
DBCHECK="${DB}.1.ht2l"
ANN=/db/mm/ann/Mus_musculus.GRCm38.91.gtf
HISAT=/an/bezara/hisat2-2.1.0/hisat2

THREADS=4
ALNDIR='hisat2'
TRIMDIR='trim'


if [[ ! -e "$REF" || ! -e "$ANN" || ! -e "$DBCHECK" || ! -e "$HISAT" ]]
then
	echo "Unable to find $REF and/or $ANN and/or $DBCHECK and/or $HISAT."
	exit
fi

NUM_READS=$(( 0 + $(ls reads/*_R1*| wc -l) ));

echo " - Input reads: $NUM_READS"
if (( $NUM_READS < 1 ));
then
	echo "No reads found in ./reads"
	exit
fi

mkdir -p "$ALNDIR"
mkdir -p "$TRIMDIR"
if [[ -e ".trimmed" ]]
then
	echo -n " - Skipping trimming: "
	cat ".trimmed"
else
	for FILE in $(ls reads/*_R1*);
        do
        	REV=${FILE/_R1/_R2}
              	BASE=$(basename $FILE | cut -f1 -d.);

		if [[ -e "$TRIMDIR/$BASE.done" ]];
		then
			echo "   - Skipping $BASE ($FILE/$REV)"
			continue;
		fi

		echo "   - Trimming $BASE"

		trim_galore -q 20 --phred33 --stringency 5 -length 30 --paired \
		        -o "$TRIMDIR" --fastqc \
		        "$FILE" \
		        "$REV" > "$TRIMDIR/$BASE.log" 2>&1
		touch "$TRIMDIR/$BASE.done";
	done

	date > ".trimmed"
fi

###
#exit;
###

if [[ -e ".aligned" ]]
then
	echo -n " - Skipping alignment: "
	cat ".aligned"
else

	echo " - Alignment step: starting"

	for FILE in $(ls $TRIMDIR/*_R1_val_1*gz);
	do

		REV=$(echo $FILE | sed 's/_R1_val_1/_R2_val_2/')
		BASE=$(basename $FILE | cut -f1,2 -d_);

		if [[ -e "$ALNDIR/$BASE.done" ]]
		then
			echo "   - Skipping $FILE"
			continue
		fi

		echo "   - Aligning $BASE ($FILE)"

		$HISAT -p $THREADS -q --dta-cufflinks -x "$DB" -1 "$FILE" -2 "$REV" \
		  --new-summary --summary-file "$ALNDIR/$BASE.summary" 2> "$ALNDIR/$BASE.hisat2.log" | \
		  samtools view -bS | samtools sort -o "$ALNDIR/$BASE.bam" -
		touch $ALNDIR/$BASE.done
	done

	# Mark step done if OK
	if (( $? < 1 ));
	then
		date > ".aligned"
	fi
fi
