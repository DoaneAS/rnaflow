#!/bin/bash
myspack
##spack load pigz

fr1=$1
fr2=$2
pair_id=$3

##source activate salmon
## remember that the 2 gzip processes each use a thread
salmon quant -l A -i index --threads 6 -o $pair_id  -1 <(gzip -cd ${fr1}) -2 <(gzip -cd ${fr2}) --validateMappings --numGibbsSamples 5 --rangeFactorizationBins 4
