# -*- coding: utf-8 -*-
import argparse as ap
import os
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# Init 
parser = ap.ArgumentParser(description='Plot metadata statistics')
parser.add_argument('--input', type=str, help='Input file')
parser.add_argument('--label', type=str, help='Prefix for plots names')
args = parser.parse_args()

label = args.label
metadata = pd.read_csv(args.input, sep=',')
PLOT_PATH = os.path.join(os.path.dirname(args.input), 'plots')
os.makedirs(PLOT_PATH, exist_ok=True)

# make plots
for c in metadata.columns:
    if c == 'Sample':
        continue
    else:
        print('Plotting statistic:', c)
        # make bar plot for every sample
        plt.figure(figsize=(14, 8))
        sns.set(style="white")
        sns.set_palette("pastel")
        sns.barplot(x=metadata['Sample'], y=metadata[c], data=metadata)
        sns.despine()
        plt.title(f'Statistic: {c}', fontsize=20)
        # det max y
        plt.ylim(0, metadata[c].max() + 1000000)
        # xticks 90
        plt.xticks(rotation=90)
        plt.savefig(
            os.path.join(PLOT_PATH, f'Stats_{label}_{c}.png'),
            bbox_inches='tight',
            dpi=300
        )
        plt.close()
        
