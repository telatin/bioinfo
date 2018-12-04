#!/bin/bash
set -exo pipefail

thispath="$( cd "$(dirname "$0")" ; pwd -P )"
VSEARCH_BIN="vsearch"
MAP_SCRIPT=$thispath/map.pl
GOLD_REFERENCE_DB=$thispath/gold.fasta

THREADS=4
OUTPUT_DIR=vsearch_output

RED='\033[0;31m'
GRN='\033[0;32m'
YLL='\033[0;33m'
CYN='\033[0;36m'
RESET='\033[0m' # No Color

echo " USAGE"
echo " $(basename $0) input_dereplicated.fasta output_directory"

if [ "NO$2" != "NO" ] && [ -d "$2" ]; then
  OUTPUT_DIR=$2
fi


if [ ! -e "$1" ]; then
    echo "Input file not found: <$1>"
    exit 1
fi

if [ NO$1 == NO ]; then
    echo -e "${RED}FATAL ERROR${RESET}: Missing parameter input FASTA file"
    exit 2
fi


if [ ! -e "$VSEARCH_BIN" ]; then
    echo -e "${RED}FATAL ERROR${RESET}:  Missing VSEARCH $VSEARCH_BIN"
    exit 11
fi

if [ ! -e "$MAP_SCRIPT" ]; then
    echo -e "${RED}FATAL ERROR${RESET}:  Missing MAP_SCRIPT $MAP_SCRIPT"
    exit 12
fi

if [ ! -e "$GOLD_REFERENCE_DB" ]; then
    echo -e "${RED}FATAL ERROR${RESET}:  Missing GOLD_REFERENCE_DB $GOLD_REFERENCE_DB"
    exit 13
fi

cd "$( cd "$(dirname "$1")" ; pwd -P )"

INPUT=$(basename $1);
START_DIR=$PWD


echo -e "${YLL} Dereplicate across samples and remove singletons${RESET}"

$VSEARCH_BIN --threads $THREADS --no_progress \
    --derep_fulllength "$INPUT" \
    --minuniquesize 2 \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --uc vsearch.derep.uc \
    --output vsearch.derep.fasta > vsearch.derep.log 2>&1

echo Unique non-singleton sequences: $(grep -c "^>" vsearch.derep.fasta)


echo echo -e "${YLL} Precluster at 98% before chimera detection${RESET}"

$VSEARCH_BIN --threads $THREADS --no_progress \
    --cluster_size vsearch.derep.fasta \
    --id 0.98 \
    --strand plus \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --uc vsearch.preclustered.uc \
    --centroids vsearch.preclustered.fasta > vsearch.preclustered.log 2>&1

echo Unique sequences after preclustering: $(grep -c "^>" vsearch.preclustered.fasta)


echo -e "${YLL} De novo chimera detection: cluster_unoise${RESET}"
$VSEARCH_BIN --no_progress --threads $THREADS --cluster_unoise vsearch.preclustered.fasta --centroids vsearch.preclustered_denoised.fasta
echo -e "${YLL} De novo chimera detection: uchime3_denovo${RESET}"
$VSEARCH_BIN --no_progress --threads $THREADS --uchime3_denovo vsearch.preclustered_denoised.fasta --nonchimeras vsearch.denovo.nonchimeras.fasta

# $VSEARCH_BIN --threads $THREADS \
#     --uchime_denovo vsearch.preclustered.fasta \
#     --sizein \
#     --sizeout \
#     --fasta_width 0 \
#     --nonchimeras vsearch.denovo.nonchimeras.fasta \

echo Unique sequences after de novo chimera detection: $(grep -c "^>" vsearch.denovo.nonchimeras.fasta)

echo -e "${YLL} Reference chimera detection${RESET}"

$VSEARCH_BIN --threads $THREADS --no_progress \
    --uchime_ref vsearch.denovo.nonchimeras.fasta \
    --db $GOLD_REFERENCE_DB \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --nonchimeras vsearch.ref.nonchimeras.fasta > vsearch.ref.nonchimeras.log 2>&1

echo Unique sequences after reference-based chimera detection: $(grep -c "^>" vsearch.ref.nonchimeras.fasta)


echo -e "${YLL} Extract all non-chimeric, non-singleton sequences, dereplicated${RESET}"

perl $MAP_SCRIPT vsearch.derep.fasta vsearch.preclustered.uc vsearch.ref.nonchimeras.fasta > vsearch.nonchimeras.derep.fasta

echo Unique non-chimeric, non-singleton sequences: $(grep -c "^>" vsearch.nonchimeras.derep.fasta)

echo -e "${YLL} Extract all non-chimeric, non-singleton sequences in each sample${RESET}"

perl $MAP_SCRIPT vsearch.derep.fasta vsearch.derep.uc vsearch.nonchimeras.derep.fasta > vsearch.nonchimeras.fasta

echo Sum of unique non-chimeric, non-singleton sequences in each sample: $(grep -c "^>" vsearch.nonchimeras.fasta)

echo -e "${YLL} Cluster at 99% and relabel with OTU_n, generate OTU table${RESET}"

$VSEARCH_BIN --threads $THREADS --no_progress \
    --cluster_size vsearch.nonchimeras.fasta \
    --id 0.99 \
    --strand plus \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --uc vsearch.clustered.uc \
    --relabel OTU_ \
    --centroids vsearch.otus.fasta \
    --otutabout vsearch.otutab.txt > vsearch.otutab.log 2>&1

echo
echo Number of OTUs: $(grep -c "^>" vsearch.otus.fasta)

cd $START_DIR
