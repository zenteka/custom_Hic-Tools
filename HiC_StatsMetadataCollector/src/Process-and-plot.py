'''
This script reads the metadata file, cleans it and plots the data.
'''

import argparse
from pathlib import Path
import os

import polars as pl
import polars.selectors as cs
import pandas as pd

import matplotlib
matplotlib.use('agg')
import matplotlib.pyplot as plt
import seaborn as sns


parser = argparse.ArgumentParser(description='Plot metadata')
parser.add_argument('-i', '--input_table', type=Path, required=True, help='Input metadata file')
parser.add_argument('-o', '--output', type=Path, required=True, help='Output directory')
args = parser.parse_args()

# check if tabel exists
if not args.input_table.exists():
    raise FileNotFoundError(f'{args.input_table} does not exist')

meta = pl.read_csv(os.fspath(args.input_table), separator='\t',
             new_columns=['Metrics',
                               'Values',
                         'Sample']).with_columns(
                             pl.col('Values').str.to_integer(base=10, strict=False)
                         ).drop_nulls().pivot(index='Sample', on='Metrics', values='Values').rename({
                             'Hi-CContacts': 'Hi-C Contacts',
                        }).drop(cs.matches('align'))

meta.write_csv(os.path.join(args.output, 'master_metadata.clean.csv'))  # Save cleaned metadata

PLOT_DIR = os.path.join(args.output, 'plots')
os.makedirs(PLOT_DIR, exist_ok=True)

# Make bar plot of smaple bny metics (for every columns
for col in meta.select(cs.numeric()).columns:
    print(f'Plotting {col}')
    toPlot = meta.select(['Sample', col]).to_pandas()
    sns.barplot(x='Sample', y=col, data=toPlot, color='steelblue')
    plt.title(f'{col} for all individual samples')
    plt.xticks(rotation=90)
    sns.despine()
    plt.savefig(os.path.join(PLOT_DIR, f'{col}.pdf'), bbox_inches='tight')
    plt.close()
