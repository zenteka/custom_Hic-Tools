#!/usr/bin/env bash
# -*- mode: shell-script -*-
# -*- coding: utf-8 -*-

# This program extracts statistics from Hi-C files and plots them.
# It can take as an input:
# 1. A directory with Hi-C files (*.hic)
# 2. A directory with subdirectories containing Hi-C expermiemtnal files (*.hic) as returned in the hic pipeline (juicer)

# Usage: bash Main.sh -i <input> -o <output>

# Check if hictk is installed
if ! command -v hictk &> /dev/null
then
    echo "hictk could not be found"
    exit 1
fi

while getopts "i:o:h" opt; do
    case $opt in
	i) INPUT=$OPTARG
	   if [ ! -d $INPUT ]; then
	       echo "Input directory does not exist"
	       exit 1
	   fi
	   ;;
	o) OUTPUT=$OPTARG
	   if [ ! -d $OUTPUT ]; then
	       mkdir -p $OUTPUT
	   fi
	   ;;
	   
	h) echo "Usage: $0 -i <input> Directory with Hi-C files or direcotry with sub-direcotries containing Hi-C experiments from hic_pipeline oputput";
           echo "          -o <output> Directory to save metadata and plots";
           exit 0;;
	\?)
	    echo "Invalid option: -$OPTARG" >&2
	   ;;
    esac  
done

source $(dirname $0)/0*.sh

# Main
fCount=$(find ${INPUT} -maxdepth 1 -name "*.hic" | wc -l)
dCount=$(find ${INPUT} -maxdepth 1 -type d | wc -l)

if [[ $fCount -gt 0 ]]; then
    echo "Hi-C maps found in $INPUT"
    echo "Processing $fCount hic files in $INPUT"
    for file in ${INPUT}/*.hic; do
        echo "Processing $file"
        get_metadata $file $OUTPUT
    done
    cat $OUTPUT/*.metadata > $OUTPUT/master_metadata.tsv
    rm $OUTPUT/*.metadata
elif [[ $dCount -gt 0 ]]; then
    echo "Found $dCount subdirectories in $INPUT"
    for dir in $INPUT/*; do
        get_metadata $dir/aligned/inter_30.hic $OUTPUT
    done
else
    echo "Neither Hi-C maps nor subdirectories found in $INPUT"
    echo "Check input!"
    exit 1
fi

# Clean and plot
python3 $(dirname $0)/0.pp.wrangle.py -i $OUTPUT/master_metadata.tsv -o $OUTPUT
rm $OUTPUT/master_metadata.tsv

python3 $(dirname $0)/1.pl-QCmetrics.py -i $OUTPUT/meta.clean.csv -o $OUTPUT

# Levrage ghostscript to merge all PDFs if available
if command -v gs &> /dev/null
then
    gs -o $OUTPUT/QC-Report.pdf \
       -dAutoRotatePages=/None \
       -sDEVICE=pdfwrite -sPAPERSIZE=a4 \
       -c "<</Orientation 3>> setpagedevice" \
       -f $OUTPUT/plots/*.pdf
else
    echo "Warning: ghostscript not found. PDFs will not be merged"
fi
echo "Done"
