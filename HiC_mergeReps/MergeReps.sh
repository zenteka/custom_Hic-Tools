#!/bin/bash
# Merge multiple hic maps.
# TODO:
# 1. Add support for cool.
# 2. Add suport for tabular input. Like this:
#    <col1> mega name <col2> sample to merge
set -euo pipefail

# This script merges multiple hic files into one.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JUICER_TOOLS="$SCRIPT_DIR/bin/juicer_tools_2.13.06.jar"
echo "JUICER_TOOLS: $JUICER_TOOLS"

# Checks to be sure
if ! command -v java &> /dev/null
then
    echo "Error: java could not be found"
    exit 1
fi

if ! java -jar ${JUICER_TOOLS} 2>&1 | grep -qw "Juicer"; then
    echo "Error: juicer tools not found"
    exit 1
fi

usage(){
    echo "Usage: $0 -i <input> -o <output> -r <resolution>"
    echo "  -i <input>   Comma separated list of hic files to merge"
    echo "  -o <output>  Output directory"
    echo "  -r <resolution> Resolution to start. This will be the lowest resolution of the new hic file"
    echo "  -t <threads> Number of threads to use. Default is $threads"
    exit 1
}


input=()
convert=0
threads=20
while getopts ":i:o:r:t:h" opt; do
    case $opt in
	i) IFS=',' read -r -a input <<< "$OPTARG";; # Get array
	o) output="$OPTARG"
	   mkdir -p "$output/aligned"
	   ;;
	r) start_resolution="$OPTARG";;
	c) convert=1;;              ;; # Convert to hic
	t) threads="$OPTARG";;
	h) usage;;
	*) echo "Invalid option -$OPTARG" >&2; usage ;;
	\?) echo "Invalid option -$OPTARG" >&2
	    exit 1
	    ;;
    esac
done
if [ ${#input[@]} -eq 0 ] || [ -z "${output:-}" ] || [ -z "${start_resolution:-}" ]; then
    echo "Error: Missing required arguments"
    usage
fi


build_mega () {
    echo "Merging hic files: $@"
    hictk merge "$@" -o ${output}/aligned/tmp.cool \
	  --resolution $start_resolution \
	  -t $threads -f -v 3
    if [ $? -ne 0 ]; then
	echo "Error: hic merge failed"
	exit 1
    fi
    hictk zoomify ${output}/aligned/tmp.cool ${output}/aligned/inter_30.mcool \
	  --nice-steps --force \
	  -t $threads -v 3
    if [ $? -ne 0 ]; then
	echo "Error: coarsening hic merge failed"
    fi
}

addnorm_juicer (){
    # Important note: Juicer cannot add resolutions. It re-computes all of them.
    # It can be very annoying. We add main resolution that we want to keep.
    java -jar $JUICER_TOOLS \
	 addNorm \
	 -r $start_resolution,$start_resolution,$start_resolution,$start_resolution \
	 -k KR,SCALE,VC,VC_SQRT \
	 -F $1 -j 30 $1
}

main(){
    echo "-------------------- Build mega --------------------"
    build_mega "${input[@]}"
    if [ $? -ne 0 ]; then
	echo "Error: hic validation failed"
	exit 1
    fi
    echo "---------------- Perfom Cis normalization ----------------"
    echo "-------------------- Balance using ICE --------------------"
    hictk balance ice ${output}/aligned/inter_30.mcool \
	  --mode cis \
	  --in-memory -v 2 -t $threads
    # convert to hic if convert set to 1
    if [ $convert -eq 1 ]; then
	echo "-------------------- Converting mcool to hic --------------------"
	hictk convert ${output}/aligned/inter_30.mcool \
	      --output ${output}/aligned/inter_30.hic \
	      --force -v 2 -t $threads
    fi
    rm -f ${output}/aligned/tmp.cool
    
}

main
echo "-------------------- Done --------------------"
