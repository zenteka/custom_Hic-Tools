#!/bin/bash
# Collect stats from the hic pipeline outpput.
# Given directory with Hi-C experiemtns, loop over inter.txt and inter_30.txt files.

set -euo pipefail

useage (){
    echo "Usage: $0 -i <input> -o <output dir to save files>"
    echo " -l <user label> -h Show this help"
    echo " Input directory should contain Hi-C experiments"
    echo " organized in the following way:"
    echo " <input_dir>/<experiment_name>/aligned"
    exit 1
}

while getopts "i:o:l:h" opt; do
    case $opt in
	i) INPUT=$OPTARG
	   if [ ! -d $INPUT ]; then
	       echo "Input directory does not exist"
	       exit 1
	   fi
	   ;;
	o) OUTPATH=$OPTARG
	   if [ ! -d $OUTPATH ]; then
	       mkdir -p $OUTPATH
	   fi
	   ;;
	l) LABEL=$OPTARG       # User label for the output may be used to
	   if [ -z ${LABEL} ]; then
	       echo "Label is required for the output master files"
	    exit 1
	fi
	;;
	h) useage;; 
	*) echo "Invalid option: -$OPTARG" >&2
	   useage
	   ;;
	\?)
	   echo "Invalid option: -$OPTARG" >&2
	   ;;
    esac  
done

SCRIPT_DIR=$(dirname $(realpath $0))

parse_sample_stats (){
    fName=$(basename $1 .txt)
    # Clean-up. The metadata is messy and needs to be cleaned up.
    grep -vE 'Juicer|WARN|Alignable|Complexity|L-I' $1 | tr -d ' ' | tr -d ',' |\
	tr ':' '\t' > $OUTPATH/${2}_${fName}.tmp
    grep -iE 'inter-c|intra|dup|hi-c|chimera|uniq|sequ|norm|compl' $OUTPATH/${2}_${fName}.tmp |\
	tr '\t' '(' | cut -d'(' -f 1,2 | tr '(' '\t' | tr -d ',' >\
							  $OUTPATH/${2}_${fName}.2tmp
    #sed -i 's/(<20Kb)/<20Kb/g' $OUTPATH/${2}_${fName}.tmp
    #sed -i 's/(>20Kb)/>20Kb/g' $OUTPATH/${2}_${fName}.tmp
    # Reorder the metadata to LONG format
    declare -A samples
    while read -r key value; do
	echo "$key $value"
	samples["$key"]="$value"	
    done < $OUTPATH/${2}_${fName}.2tmp
    
    ## Get header if needeod
    first_line=$(printf "%s," "${!samples[@]}")
    first_line=${first_line%,} # remove trailing comma
    # Dump first line as header if not in the dierctory
    if [ ! -f $OUTPATH/header.txt ]; then
	first_line="Sample,$first_line"
	echo -e "$first_line" > $OUTPATH/header.txt
    fi
    ## Get values
    value_line=$(printf "%s," "${samples[@]}")
    value_line=${value_line%,} # remove trailing comma
    value_line="${2},${value_line}"
    echo -e "$value_line" > $OUTPATH/${2}_${fName}.txt
}

for dir in $INPUT/*; do
    # check if directory contains inter.txt and inter_30.txt files
    if [ -d $dir/aligned ]; then
	if [ -f $dir/aligned/inter.txt ]; then
	    name=$(basename $dir)
	    # do some magic
	    if [ -f $dir/aligned/inter.txt ]; then
		echo "Found inter.txt file for sample ${name}. Parsing..."
		parse_sample_stats $dir/aligned/inter.txt ${name} 
	    fi
	    if [ -f $dir/aligned/inter_30.txt ]; then
		echo "Found inter_30.txt file for sample ${name}. Parsing..."
		parse_sample_stats $dir/aligned/inter_30.txt ${name}
	    fi
	fi
    else
	echo "Directory $dir does not contain aligned files"
	echo "Skipping $dir"
    fi
done

# Make tsv files
cat $OUTPATH/*_inter.txt > $OUTPATH/Stats_unfiltered.tmp
cat $OUTPATH/*_inter_30.txt > $OUTPATH/Stats_MAPQ30-filtered.tmp

# prepend to header for both files
cat $OUTPATH/header.txt $OUTPATH/Stats_unfiltered.tmp > $OUTPATH/${LABEL}_Stats_unfiltered.csv
cat $OUTPATH/header.txt $OUTPATH/Stats_MAPQ30-filtered.tmp > $OUTPATH/${LABEL}_Stats_MAPQ30-filtered.csv

# Clean up
rm $OUTPATH/*_inter.txt $OUTPATH/*_inter_30.txt $OUTPATH/header.txt $OUTPATH/*tmp

# Plot
python3 $SCRIPT_DIR/make_barplt.py \
	--input $OUTPATH/${LABEL}_Stats_MAPQ30-filtered.csv \
	--label $LABEL 
