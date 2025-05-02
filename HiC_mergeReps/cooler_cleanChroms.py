'''
Remove unwanted chromosomes from a cooler file.
It will keep only autosomes + chrX + chrY.
Use polars for fast filtering.
'''
import os
import argparse
import cooler
import polars as pl

# Init        
def parse_args():
    parser = argparse.ArgumentParser(
        description="Remove unwanted chromosomes from a cooler file."
    )
    parser.add_argument("--input", "-i", dest="input", required=True, help="Input cooler file")
    parser.add_argument("--output", "-o", dest="output", required=True, help="Output cooler file")
    parser.add_argument("--resolution", "-r", dest="resolution", required=True, help="Resolution of the cooler file")
    return parser.parse_args()

args = parse_args()
c_file = args.input
o_file = args.output
res = args.resolution

# autosomes + chrX + chrY only
chroms_to_keep = [ 'chr1', 'chr2', 'chr3', 'chr4', 'chr5', 'chr6', 'chr7', 'chr8', 'chr9', 'chr10',
                   'chr11', 'chr12', 'chr13', 'chr14', 'chr15', 'chr16', 'chr17', 'chr18', 
                   'chr19', 'chr20', 'chr21', 'chr22', 'chrX', 'chrY']
print ( "-------------------- Chromosomes to keep --------------------")
print (chroms_to_keep)

print(f"-------------------- Reading cooler --------------------")
#test = '/home/kpiera/syncd/DevAll_shared/tmp/HIC_001_D64_A1_cat_inter30.mcool::resolutions/10000'
C = cooler.Cooler(c_file)

bins = C.bins()[:]
bins['chrom'] = bins['chrom'].astype(str)
bins['old_id'] = bins.index
bins_fast = pl.from_pandas(bins)

print ( "-------------------- Filtering bins --------------------")

bins_to_keep = bins_fast.filter(
    pl.col('chrom').is_in(chroms_to_keep)
).to_pandas()

valid_old_ids = set(bins_to_keep['old_id'].values)

print ( "-------------------- Filtering pixels --------------------")

pixels_clean = pl.from_pandas(C.pixels()[:]).filter(
(pl.col('bin1_id').is_in(valid_old_ids)) & (pl.col('bin2_id').is_in(valid_old_ids))
).to_pandas()

print ( "-------------------- Writing to new cooler --------------------")
cooler.create_cooler(
    o_file,
    bins=bins_to_keep, pixels=pixels_clean,
    ordered=True,
    assembly=C.info.get("assembly"), metadata=C.info.get("metadata")
)
print ( "-------------------- Done --------------------")
