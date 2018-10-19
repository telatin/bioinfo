#!/bin/bash -e

dbref=/tgac/software/testing/sortmerna/2.1b/x86_64/sortmerna/rRNA_databases


ref="$dbref/rfam-5.8s-database-id98.fasta,$dbref/rfam-5.8s-database-id98:$dbref/rfam-5s-database-id98.fasta,$dbref/rfam-5s-database-id98:$dbref/silva-arc-16s-id95.fasta,$dbref/silva-arc-16s-id95:$dbref/silva-arc-23s-id98.fasta,$dbref/silva-arc-23s-id98:$dbref/silva-bac-16s-id90.fasta,$dbref/silva-bac-16s-id90:$dbref/silva-bac-23s-id98.fasta,$dbref/silva-bac-23s-id98:$dbref/silva-euk-18s-id95.fasta,$dbref/silva-euk-18s-id95:$dbref/silva-euk-28s-id98.fasta,$dbref/silva-euk-28s-id98"

if [[ -z ${2+x} ]]; then
	echo "USAGE: sortmerna_qi.sh <input.fastq> <outdir> [memory]"
	exit;
fi
input=$1
outdir=$2

if [[ -z ${3+x} ]]; then
	memory=20000;
else
	memory=$3
fi
if [ ! -d "$outdir" ]; then
	echo " USAGE: <FastqInterleaved> <Outdir>"
	echo " Output directory not found ($outdir)"
	exit 4
fi
source switch-institute ei
source sortmerna-2.1b
set -euxo pipefail
name=$(basename $1 |cut -f1 -d.)
sortmerna --ref $ref --reads $1 --fastx \
	--aligned $outdir/$name.rRNA \
	--other $outdir/$name.nonrRNA \
	--paired_out --log -a $THIS_JOB_CORES -m $memory > $outdir/$name.sortmerna.log 2>&1


