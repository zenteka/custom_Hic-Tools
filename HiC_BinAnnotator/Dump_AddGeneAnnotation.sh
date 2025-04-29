#!/bin/bash
#+Author: Karol Piera
#+Date: 2024-12-120
# Annotate DUMP file witha given genomic feautres.

# check if bedtools installed
if command -v bedtools >/dev/null 2>&1; then
    echo "Preprocess DUMP file"
else
    echo "bedtools not found. Please install bedtools"
    exit 1
fi

# Map gene names strings to bins in the DUMP file
# See h) for details

while getopts ":i:a:p:h" opt; do
    case $opt in
        i) DUMP_FILE=$OPTARG ;;
        a) sort -k1,1 -k2,2n $OPTARG > ./annotation.sorted.tmp  # LEXICOGRAPHIC ANNOTATION
           ANNOTATION=./annotation.sorted.tmp
           ;;
        p) threads=$OPTARG ;;
        h)
            echo "Usage: Atlas_AnnotateDunmp.sh -i <DUMP_FILE> -a <ANNOTATION>"
            echo "Annotate bins to thier corresponding genomic features"
            echo "Options:"
            echo "  -i  DUMP_FILE    DUMP file to be annotated"
            echo "  -a  ANNOTATION   Genomic features to be used for annotation"
            echo "  -p  THREADS      Number of threads to use. Default 15"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done
# if no threads specified, use 15
if [ -z $threads ]; then
    threads=15
fi

if [ -z $DUMP_FILE ] || [ -z $ANNOTATION ]; then
    echo "Missing arguments"
    exit 1
fi

# Get the header from the DUMP file
get_header(){
    if [ $(head -n 1 $1 | grep -c 'start') -eq 0 ]; then
        header=('chrom1' 'start1' 'end1'\
                         'chrom2' 'start2' 'end2' 'contacts'\
                'Bin1_Genes' 'Bin2_Genes')
        echo "No header found in the DUMP file. Using default header"
    else
        # load header from the DUMP file as first line
        header=($(head -n 1 $DUMP_FILE))
        header+=('Bin1_Genes' 'Bin2_Genes')
        # remove the header from the DUMP file
        tail -n +2 $DUMP_FILE > ./0.tmp
        DUMP_FILE=./0.tmp
    fi
    echo -e "${header[@]}" | tr ' ' '\t' > ./header
}

get_bins() {
    cut -f 1-3 $1 | sort -k1,1 -k2,2n --parallel $threads > ./Bin1.sorted.tmp
    cut -f 4-6 $1 | sort -k1,1 -k2,2n --parallel $threads > ./Bin2.sorted.tmp
}

annotate_dump() {
    FileName=$(basename $1)
    
    bedtools map -a ./Bin1.sorted.tmp -b $ANNOTATION \
             -c 4 -o distinct -null 'NA' > ./Bin1_annotated.tmp
    bedtools map -a ./Bin2.sorted.tmp -b $ANNOTATION \
             -c 4 -o distinct -null 'NA' > ./Bin2_annotated.tmp
    
    sort -k1,1 -k2,2n --parallel $threads $DUMP_FILE > ./dump.sorted.tmp
    paste ./dump.sorted.tmp <(cut -f 4 ./Bin1_annotated.tmp) > ./1.tmp
    sort -k4,4 -k5,5n --parallel $threads ./1.tmp > ./dump.sorted2.tmp 
    paste ./dump.sorted2.tmp <(cut -f 4 ./Bin2_annotated.tmp) > ./2.tmp
    sort -k1,1 -k2,2n -k4,4 -k4,4n --parallel $threads ./2.tmp > ./2.sorted.tmp
    cat ./header ./2.sorted.tmp > $FileName.annotated.tsv
}

# Main
get_header $DUMP_FILE
get_bins $DUMP_FILE
echo "Annotating"
annotate_dump $DUMP_FILE
rm ./*.tmp ./header  # Clean up
