#!/bin/bash
set -eo pipefail
INPUT_FILE=$1;
OUTPUT_FILE=$2;


if [ ! -e $INPUT_FILE ]; then
	echo "Input file missing (raw_tax.txt)"
	exit 1
else
	echo "#Input: $INPUT_FILE"
fi

if [ NO$OUTPUT_FILE == NO ]; then
	echo "Missing output file name"
	exit 2
else
	echo "#Output: $OUTPUT_FILE"
fi

TMP_DIR=$(mktemp -d);
echo "#Tmp:    $TMP_DIR"


# THIS WAS THE ORIGINAL SCRIPT FOR THE 4 COLUMN USEARCH OUTPUT
sed  's/#OTU ID//' "$INPUT_FILE" > "$TMP_DIR/raw_taxonomy.txt"
cut -f1 "$TMP_DIR/raw_taxonomy.txt" > $TMP_DIR/ASV_IDs
cut -f4 "$TMP_DIR/raw_taxonomy.txt" > $TMP_DIR/raw_tax

cut -d : -f2 $TMP_DIR/raw_tax | cut -d , -f1 | sed 's/\"//g' > $TMP_DIR/domain
cut -d : -f3 $TMP_DIR/raw_tax | cut -d , -f1 | sed 's/\"//g' > $TMP_DIR/phylum
cut -d : -f4 $TMP_DIR/raw_tax | cut -d , -f1 | sed 's/\"//g' > $TMP_DIR/class
cut -d : -f5 $TMP_DIR/raw_tax | cut -d , -f1 | sed 's/\"//g' > $TMP_DIR/order
cut -d : -f6 $TMP_DIR/raw_tax | cut -d , -f1 | sed 's/\"//g' > $TMP_DIR/family
cut -d : -f7 $TMP_DIR/raw_tax | cut -d , -f1 | sed 's/\"//g' > $TMP_DIR/genus
cut -d : -f8 $TMP_DIR/raw_tax | cut -d , -f1 | sed 's/\"//g' > $TMP_DIR/species

paste $TMP_DIR/ASV_IDs $TMP_DIR/domain $TMP_DIR/phylum $TMP_DIR/class $TMP_DIR/order $TMP_DIR/family $TMP_DIR/genus $TMP_DIR/species > $TMP_DIR/tax_temp

echo -e "\tDomain\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies" > $TMP_DIR/header

cat $TMP_DIR/header $TMP_DIR/tax_temp > "$OUTPUT_FILE"

rm "$TMP_DIR/raw_taxonomy.txt"  $TMP_DIR/ASV_IDs $TMP_DIR/raw_tax $TMP_DIR/domain \
	 $TMP_DIR/phylum $TMP_DIR/class $TMP_DIR/order $TMP_DIR/family $TMP_DIR/genus $TMP_DIR/species $TMP_DIR/tax_temp $TMP_DIR/header
rm -rf $TMP_DIR
