'''
Make bar plots of every QC metrics for all samples.

Saves indivudal plots to the output directory.

'''
import os
import argparse
from pathlib import Path

import pandas as pd

# Set to headless mode (otherwise python subprocesses will get stuck)
import matplotlib
matplotlib.use('agg')

import matplotlib.pyplot as plt

import seaborn as sns

parser = argparse.ArgumentParser(description='Plot metadata')
parser.add_argument('-i', '--input_table', type=Path, required=True, help='Input metadata file')
parser.add_argument('-o', '--output', type=Path, required=True, help='Output directory')
args = parser.parse_args()

meta = pd.read_csv(os.fspath(args.input_table))

# Plots
PLOTS = os.path.join(args.output, 'plots')
os.makedirs(PLOTS, exist_ok=True)
# how do I remove str from list in python?
# https://stackoverflow.com/questions/1157106/remove-all-occurrences-of-a-value-from-a-list

stats = meta.columns.to_list()
stats.remove('Sample')

for col in stats:
    print(f'Plotting {col}')
    sns.barplot(x='Sample', y=col, data=meta, color='steelblue')
    plt.title(f'{col} for all individual samples')
    plt.xticks(rotation=90)
    sns.despine()
    plt.savefig(os.path.join(PLOTS, f'{col}.pdf'), bbox_inches='tight')
    plt.close()
