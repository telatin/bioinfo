#!/bin/bash
# Annotate a FASTA file using VSEARCH

this_script_path="$( cd "$(dirname "$0")" ; pwd -P )"
vsearch_bin_path="vsearch"
convert_script="$this_script_path/convert_usearch_tax.sh"

silva_db_path="/git/local_db/silva_16s_v123.fa"
rdp_db_path="$this_script_path/../db/rdp_16s_v16.fa"
identity_cutoff=0.8
threads=4
opt_do_rdp=1
opt_do_silva=0

echo " USAGE:
$(basename $0) [options] Input_Fasta [Output_File]

  -s         Enable annotation with SILVA (def: only RDP)
  -t INT     Threads [$threads]
  -i FLOAT   Identity threshold [$identity_cutoff]
";

while getopts t:i:v:s option
do
	case "${option}"
		in
			t) threads=${OPTARG};;
			i) identity_cutoff=${OPTARG};;
			v) vsearch_bin_path=${OPTARG};;
			s) opt_do_silva=1;;
			?) echo " Wrong parameter $OPTARG";;
	 esac
done
shift "$(($OPTIND -1))"



if [ ! -e "$vsearch_bin_path" ]; then
	echo "VSEARCH binary not found at: $vsearch_bin_path"
	exit 1;
fi

if [ ! -e "$rdp_db_path" ]; then
        echo "VSEARCH database RDP not found at: $silva_db_path"
        exit 2;
fi

if [ ! -e "$1" ]; then
	echo "Input file (FASTA) not found: \"$1\""
	exit 3
fi

OUTPUT_BASE_NAME="$(dirname $1)/$(basename $1 | rev | cut -f 2- -d . | rev )"
if [[ ! -z ${2+x} ]]; then
	OUTPUT_BASE_NAME=$2
fi

echo "#Input file:  $1"
echo "#Output file: $OUTPUT_BASE_NAME"
echo "#Identity:    $identity_cutoff [-i FLOAT]"
echo "#Database1:   $rdp_db_path"


if [ $opt_do_silva ] && [ ! -e "$silva_db_path" ]; then
        echo "VSEARCH database SILVA not found at: $silva_db_path"
        exit 4;
fi


set -euo pipefail
$vsearch_bin_path  --no_progress --threads $threads --sintax "$1" --db "$rdp_db_path"   --tabbedout "$OUTPUT_BASE_NAME.rdp.txt"   \
	--sintax_cutoff $identity_cutoff >> "$OUTPUT_BASE_NAME.rdp.log" 2>&1

# Annotate with SILVA
if [ $opt_do_silva -eq 1 ]; then
				echo "#Database2:   $silva_db_path [-s]"
				$vsearch_bin_path   --no_progress --threads $threads --sintax "$1" --db "$silva_db_path" --tabbedout "$OUTPUT_BASE_NAME.silva.txt" 	\
				--sintax_cutoff $identity_cutoff >> "$OUTPUT_BASE_NAME.silva.log" 2>&1
fi


# Convert taxonomy format

if [ -e "$convert_script" ]; then
	bash $convert_script "$OUTPUT_BASE_NAME.rdp.txt"   "$OUTPUT_BASE_NAME.rdp.tsv"
	if [ $opt_do_silva -eq 1 ]; then
  	bash $convert_script "$OUTPUT_BASE_NAME.silva.txt" "$OUTPUT_BASE_NAME.silva.tsv"
	fi
else
	echo "Convert script not found <$convert_script>: skipping step"
fi
