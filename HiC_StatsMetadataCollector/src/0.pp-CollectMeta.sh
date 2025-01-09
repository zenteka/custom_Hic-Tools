#!/usr/bin/env bash
# -*- mode: shell-script -*-
# -*- coding: utf-8 -*-

# Extract Metadata from Hi-C maps using hictk
get_metadata() {
    # chck input if is a file or direcotry
    if [ -f $1 ]; then
        fName=$(echo $1 |\
                    rev | cut -d'/' -f 1 | rev |\
                    cut -d'.' -f 1)
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
