#!/bin/bash

set -euo pipefail


opt_help=0;
threads=4;
while getopts t:h option
do
        case "${option}"
                in
                        t) threads=${OPTARG};;
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
    FILE2=${FILE1/_R1/R2};
fi

if  [[ $FILE1 == $FILE2 ]]; then
    echo "ERROR: Unable to guess R2, or R2=R1. please specify correct R2 file"
    exit 3
fi

if [ ! -e "$FILE2" ]; then
    echo "ERROR: File R2 not found: <$FILE2>";
    exit 1
fi

###
