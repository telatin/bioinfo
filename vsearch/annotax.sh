#!/bin/bash
# Annotate a FASTA file using VSEARCH

# Script directory, to locate dependencies
this_script_path="$( cd "$(dirname "$0")" ; pwd -P )"
convert_script="$this_script_path/convert_usearch_tax.sh"

# Databases
rdp_db_path="$this_script_path/db/rdp_16s_v16.fa"
silva_db_path="$this_script_path/db/silva_16s_v123.fa"

# VSEARCH full path (can be user-supplied with -v)
vsearch_bin_path=$(command -v "vsearch")

# Defaults
identity_cutoff=0.8
threads=2
opt_do_rdp=1
opt_do_silva=0

echo "
 USAGE:
 $(basename $0) [options] Input_Fasta [Output_BaseName]

  -t INT     Threads [$threads]
  -i FLOAT   Identity threshold [$identity_cutoff]
  -v STRING  Path to VSEARCH [$vsearch_bin_path]
  -s         Also annotate with 2nd db (default: only 1st)
  -1 STRING  Path to first db, RDP ($rdp_db_path)
  -2 STRING  Path to second db, SILVA ($silva_db_path)
";

while getopts t:i:v:s option
do
	case "${option}"
		in
			t) threads=${OPTARG};;
			i) identity_cutoff=${OPTARG};;
			v) vsearch_bin_path=${OPTARG};;
			s) opt_do_silva=1;;
			1) rdp_dp_path=${OPTARG};;
			2) silva_db_path=${OPTARG};;
 			?) echo " Wrong parameter $OPTARG";;
	 esac
done
shift "$(($OPTIND -1))"



if [ ! -e "$vsearch_bin_path" ];
then
	echo "VSEARCH (2.11) should be available in the PATH"
	exit;
fi


if [ ! -e "$rdp_db_path" ]; then
        echo "VSEARCH database RDP not found at: $rdp_db_path"
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


if [ $opt_do_silva -gt 0 ] && [ ! -e "$silva_db_path" ]; then
        echo "VSEARCH database SILVA not found at: $silva_db_path"
        exit 4;
fi


set -euo pipefail
$vsearch_bin_path  --no_progress --threads $threads --sintax "$1" --db "$rdp_db_path"   --tabbedout "$OUTPUT_BASE_NAME.rdp.txt"   \
	--sintax_cutoff $identity_cutoff >> "$OUTPUT_BASE_NAME.rdp.log" 2>&1


if [[ $opt_do_silva -gt 0 ]]; 
then
	if [ ! -e "$silva_db_path" ]; then
		echo "SKIPPING: Annotation with Silva: db not found <$silva_db_path>"
	else
        echo "#Database2:   $silva_db_path [-s]"
	        $vsearch_bin_path   --no_progress --threads $threads --sintax "$1" --db "$silva_db_path" --tabbedout "$OUTPUT_BASE_NAME.silva.txt"      \
       	        --sintax_cutoff $identity_cutoff >> "$OUTPUT_BASE_NAME.silva.log" 2>&1
	fi

fi

# Convert taxonomy format

if [ -e "$convert_script" ]; then
	bash $convert_script "$OUTPUT_BASE_NAME.rdp.txt"   "$OUTPUT_BASE_NAME.rdp.tsv"   > "$OUTPUT_BASE_NAME.rdp_conversion.log" 2>&1
	if [ $opt_do_silva -eq 1 ]; then
  	bash $convert_script "$OUTPUT_BASE_NAME.silva.txt" "$OUTPUT_BASE_NAME.silva.tsv" > "$OUTPUT_BASE_NAME.sil_conversion.log" 2>&1
	fi
else
	echo "SKIPPING: Convert script not found <$convert_script>"
fi
