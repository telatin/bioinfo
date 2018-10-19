#!/bin/bash

set -euo pipefail

this_script_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )";
tools_dir="$this_script_path/tools_sample_processor"
opt_help=0;
threads=4;
outdir='processed_sample';

### CHECK DEPENDENCIES

for FILE in deinterleave.sh merge-paired-reads.sh sortmerna.sh; do
    if  [ ! -e "$tools_dir/$FILE" ]; then
        echo " FATAL ERROR: Unable to find required script <$FILE> in <$tools_dir>";
        exit 3
    fi 
done
echo " * Internal dependencies found"

for COMMAND in ls sb.pl; do

    command -v "$COMMAND" > /dev/null ||  (echo " FATAL ERROR: Unable to find dependency in path <$COMMAND>"; exit 8)

done
echo " * External commands found"

### GET ARGUMENTS
while getopts t:o:h option
do
        case "${option}"
                in
                        t) threads=${OPTARG};;
                        o) outdir=${OPTARG};;
                        h) opt_help=1;;
                        ?) echo " Wrong parameter $OPTARG";;
         esac
done
shift "$(($OPTIND -1))"

if [[ $opt_help -eq 1 || -z ${1+x} ]]; then
echo " USAGE:
$(basename $0) [options] FirstPair.fq [SecondPair.fq]

  -t INT     Threads [$threads]
  -h         Show this message [$opt_help]
";
exit;
fi

### FILE R1 AND R2 VALIDATION
FILE1=$1;

if [ ! -e "$FILE1" ]; then
    echo "ERROR: File R1 not found: <$FILE1>";
    exit 1
fi

if [ ! -z ${2+x} ]; then
    FILE2=$2
else
    FILE2=${FILE1/_R1/_R2};
fi

if  [[ $FILE1 == $FILE2 ]]; then
    echo "ERROR: Unable to guess R2, or R2=R1. please specify correct R2 file"
    exit 3
fi

if [ ! -e "$FILE2" ]; then
    echo "ERROR: File R2 not found: <$FILE2>";
    exit 1
fi


## CREATE DIRECTORY

BASE=$(basename "$FILE1" | cut -f1 -d.  | cut -f1 -d_)

# Gunzip?

if [ -d "$outdir" ]; then
        echo " * Output directory found: <$outdir>"
else
    echo " * Attempt creating output directory <$outdir>"
    mkdir -p "$outdir"
fi

CMD1="${tools_dir}/merge-paired-reads.sh \"$FILE1\" \"$FILE2\" \"$outdir\"/\"${BASE}.interleaved.fastq\"";
ID1=`sb.pl --cores 1 --name $BASE.1 --run "$CMD1"`
ID1=$(echo $ID1 | cut -f2 -d:)

CMD2="${tools_dir}/sortmerna.sh \"$outdir\"/\"${BASE}.interleaved.fastq\" \"$outdir/\" ";
ID2=`sb.pl --cores 4 --name $BASE.2 --after $ID1 --run "$CMD2"`
ID2=$(echo $ID2 | cut -f2 -d:)




