#!/bin/bash
#
#	script: merges two fastq paired-reads files into one file
# prerequisites: 
#
# (1) Scenario: Paired-end forward and reverse reads, 2 files
#
#          READ 1
#    |-------------->
# 5' |-------------------------------------------------| 3'
#      | | | | | | | | | | | | | | | | | | | | | | | |
# 3' |-------------------------------------------------| 5'
#                                       <--------------|
#                                            READ 2
#
#    See "Example 5: sortmerna on forward-reverse paired-end
#    reads (2 input files)" of the SortMeRNA User Manual (version 1.7 
#    and higher)
#
#    Use merge-paired-reads.sh to interweave the reads from
#    both files into a single file, where READ 1 will be
#    directly followed by READ 2
#
# command: bash merge-paired-reads.sh file1.fastq file2.fastq outputfile.fastq
#
# Use the outputfile.fastq as input reads to SortMeRNA
#
# date: March 26, 2013
# contact: evguenia.kopylova@lifl.fr
#

# check all files are given
if [ $# -lt 3 ]; then
 echo "usage: $0 forward-reads.fastq reverse-reads.fastq merged-reads.fastq"
 exit 2
elif [ $# -gt 3 ]; then
 echo "usage: $0 forward-reads.fastq reverse-reads.fastq merged-reads.fastq"
 exit 2
fi

# merge the files
echo "   Processing $1 .."
perl -pe 's/\n/\t/ if $. %4' $1 > $3.READS1
echo "   Processing $2 .."
perl -pe 's/\n/\t/ if $. %4' $2 > $3.READS2
echo "   Interleaving $1 and $2 .."
paste -d '\n' $3.READS1 $3.READS2 | tr "\t" "\n" > $3

rm $3.READS1 $3.READS2
