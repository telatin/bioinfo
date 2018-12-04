#!/bin/bash
set -exo pipefail

# Retrieve the _script_ parent directory
thispath="$( cd "$(dirname "$0")" ; pwd -P )";

# Script _execution_ directory
initialpath=$PWD;


# If vsearch is not in path, alter this line:

VSEARCH_BIN="vsearch"
MAP_SCRIPT="$thispath/map.pl"
PROCESSOR_SCRIPT="$thispath/vsearch_derep_processor.sh"
ANNOTAX_SCRIPT="$thispath/annotax.sh"
GOLD_REFERENCE_DB="$thispath/gold.fasta"
RDP_DB="$thispath/rdp_16s_v16.fa"

THREADS=4
INPUT_DIR='./';
OUTPUT_DIR='./vsearch_output'

identity_cutoff=0.8

# Amplicon size boundaries
MIN_LEN=200
MAX_LEN=300

STRIP_LEFT=20
STRIP_RIGHT=20

# Declare color codes
RED='\033[0;31m'
GRN='\033[0;32m'
YLL='\033[0;33m'
CYN='\033[0;36m'
RESET='\033[0m'  # No Color


echo -e "${GRN}VSEARCH ANALYSIS PIPELINE${RESET}
";

echo -e "${YLL} USAGE
 $(basename $0) [options -i INPUT_DIR -o OUTPUT_DIR]${RESET}

    -i INPUT_DIR [$INPUT_DIR]
    -o OUTPUT_DIR [$OUTPUT_DIR]
    -c IDENTITY_CUTOFF [$identity_cutoff]
    -l STRIP_LEFT [$STRIP_LEFT]
    -r STRIP_RIGHT [$STRIP_RIGHT]
    -m MIN_MERGE_LEN [$MIN_LEN]
    -x MAX_MERGE_LEN [$MAX_LEN]

";


while getopts i:o:c:l:r:m:x: option
do
	case "${option}"
		in
			i) INPUT_DIR=${OPTARG};;
			o) OUTPUT_DIR=${OPTARG};;
			c) identity_cutoff=${OPTARG};;
			l) STRIP_LEFT=${OPTARG};;
			r) STRIP_RIGHT=${OPTARG};;
			m) MIN_LEN=${OPTARG};;
			x) MAX_LEN=${OPTARG};;
			?) echo " Wrong parameter $OPTARG";;
	 esac
done
shift "$(($OPTIND -1))"

mkdir -p ${OUTPUT_DIR}
echo "
#Input_dir    $INPUT_DIR
#Output_dir   $OUTPUT_DIR
#IdentityCut  $identity_cutoff
#MergeLen     $MIN_LEN-$MAX_LEN
#TrimPrimers  $STRIP_LEFT-$STRIP_RIGHT
"

if [ ! -e "$PROCESSOR_SCRIPT" ] || [ ! -e "$MAP_SCRIPT" ] || [ ! -e "$ANNOTAX_SCRIPT" ]; then
	echo "ERROR: <$VSEARCH_BIN> or <$PROCESSOR_SCRIPT> or <$MAP_SCRIPT> or <$ANNOTAX_SCRIPT> not found."
	exit 1;
fi

if [ ! -e $GOLD_REFERENCE_DB ]; then
	echo "ERROR: Reference db <$GOLD_REFERENCE_DB> not found"
	cd $initialpath
	exit 2;
fi



COUNT=$(ls ${INPUT_DIR}/*_R[12]*|wc -l)
if [ $COUNT -lt 2 ]
then
	echo "ERROR: Not enough FASTQ files to analyze ($COUNT < 2)"
	cd $initialpath
	exit 10
fi
echo "File to analyze: $COUNT"



C=0;

# Merge and filter all FASTQ paired ends:

for INPUT_FILE in ${INPUT_DIR}/*_R1*fastq;
do
	let C=$C+1
	BASENAME=$(basename ${INPUT_FILE});
	OUT=$(basename $INPUT_FILE| cut -f1 -d_);

	echo -e "${CYN}  == [$C.1] $OUT Merge pairs${RESET}"
	$VSEARCH_BIN --threads $THREADS --no_progress --fastq_mergepairs "$INPUT_DIR/$BASENAME" --reverse "$INPUT_DIR/${BASENAME/_R1/_R2}" \
				--fastq_minovlen 100 \
        --fastq_maxdiffs 45 \
        --fastqout "$OUTPUT_DIR/$OUT.merged.fastq" \
        --fastq_eeout --threads $THREADS >> "$OUTPUT_DIR/$OUT.log" 2>&1

	echo -e "${CYN}  == [$C.2] $OUT stats${RESET}"
	$VSEARCH_BIN  --threads $THREADS --no_progress  \
        --fastq_eestats "$OUTPUT_DIR/$OUT.merged.fastq" \
        --output "$OUTPUT_DIR/$OUT.stats" >> $OUTPUT_DIR/$OUT.log 2>&1

  echo -e "${CYN}  == [$C.3] $OUT Quality filtering${RESET}"
  $VSEARCH_BIN  --threads $THREADS --no_progress \
        --fastq_filter "$OUTPUT_DIR/$OUT.merged.fastq" \
        --fastq_maxee 0.5 \
        --fastq_minlen $MIN_LEN \
        --fastq_maxlen $MAX_LEN \
        --fastq_maxns 0 \
        --fastq_stripleft  $STRIP_LEFT \
        --fastq_stripright $STRIP_RIGHT \
        --fastaout "$OUTPUT_DIR/$OUT.filtered.fasta" \
        --fasta_width 0 >> "$OUTPUT_DIR/$OUT.log" 2>&1

  echo -e "${CYN}  == [$C.4] $OUT Dereplicate at sample level and relabel${RESET}"
  $VSEARCH_BIN --threads $THREADS --no_progress \
        --derep_fulllength "$OUTPUT_DIR/$OUT.filtered.fasta" \
        --strand plus \
        --output "$OUTPUT_DIR/$OUT.derep.fasta" \
        --sizeout \
        --uc "$OUTPUT_DIR/$OUT.derep.uc" \
        --relabel $OUT. \
        --fasta_width 0 >> "$OUTPUT_DIR/$OUT.log" 2>&1

done


# ------



echo -e "${YLL} Merge all samples${RESET}"

PREV_DIR="$initialpath"
cd "$OUTPUT_DIR"

# Merge all fasta files
rm -f vsearch.*
ls *derep.fasta   > vsearch.input.txt
cat *.derep.fasta > vsearch.samples.fasta

# A script will produce the OTU table starting from the labelled merged file:
echo -e "${YLL} Processing vsearc.samples.fasta with <$PROCESSOR_SCRIPT>${RESET}"
$PROCESSOR_SCRIPT vsearch.samples.fasta

# A script will annotate the taxonomy of the  OTU fasta file:
echo -e "${YLL} Runnging annotation <$ANNOTAX_SCRIPT>${RESET}"
$ANNOTAX_SCRIPT -s -i $identity_cutoff vsearch.otus.fasta

