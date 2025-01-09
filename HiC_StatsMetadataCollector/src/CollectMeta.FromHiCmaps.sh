#!/usr/bin/env bash
# -*- mode: shell-script -*-
# -*- coding: utf-8 -*-

if ! command -v hictk &> /dev/null
then
    echo "hictk could not be found"    
    exit
fi

# Given a directory with Hi-C output of colect metadata from each file.
# Master metadata file will be built.

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
	   
	h) echo "Usage: $0 -i <input> -o <output>"; exit 0;;
	\?)
	   echo "Invalid option: -$OPTARG" >&2
	   ;;
    esac  
done

# %% Define functions
get_metadata() {
    # chck input if is a file or direcotry
    if [ -f $1 ]; then
        fName=$(echo $1 | rev | cut -d'/' -f 1 | rev | cut -d'.' -f 1)
    elif [ -d $1 ]; then
        fName=$(basename $1)
        echo "Processing $fName"
    else
        echo "Incorrect input"
        exit 1
    fi
       
    #fName=$(echo $1 | rev | cut -d'/' -f 3 | rev | cut -d'.' -f 1)
    echo "Processing $fName"
    echo -e $(hictk metadata $1 | grep "Sequ" | cut -d'\' -f 4-) |\
	grep -vE 'WARN|Alignable' |\
	tr -d ' ' |\
	tr ':' '\t' |\
	grep -iE 'inter-c|dup|intra|hi-c|chimera|uniq|sequ|norm|compl' |\
	tr '\t' '(' | cut -d'(' -f 1,2 | tr '(' '\t' | tr -d ',' >\
					    $2/${fName}.metadata.tmp
    # add 3rd column with the filename
    awk -v OFS='\t' -v fName=$fName '{print $0, fName}'\
	$2/${fName}.metadata.tmp > $2/${fName}.metadata &&\
        rm $2/${fName}.metadata.tmp
}

# check if input is direcotry with *.hic or is a directory with subdirectories
if [ $(wc -l <<< $(find $INPUT -maxdepth 1 -name "*.hic")) -gt 0 ]; then
    echo "Processing all *.hic files in $INPUT"
    for file in $INPUT/*.hic; do
        get_metadata $file $OUTPUT
    done
    cat $OUTPUT/*.metadata > $OUTPUT/master_metadata.tsv
    rm $OUTPUT/*.metadata
elif [ $(wc -l <<< $(find $INPUT -maxdepth 1 -type d)) -gt 0 ]; then
    echo "Processing all *.hic files in subdirectories of $INPUT"
    for dir in $INPUT/*; do
        get_metadata $dir/aligned/inter_30.hic $OUTPUT
    done
else
    echo "No *.hic files found in $INPUT"
    exit 1
fi

# Clean and pivot metadata, then plot
python3 $(dirname $0)/Process-and-plot.py -i $OUTPUT/master_metadata.tsv -o $OUTPUT
rm $OUTPUT/master_metadata.tsv

# Merge pdfs if possible
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
