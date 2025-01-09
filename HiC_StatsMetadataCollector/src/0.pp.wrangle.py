'''
This script reads the metadata file, cleans it and plots the data.
'''

import argparse
from pathlib import Path
import os

import polars as pl
import polars.selectors as cs

parser = argparse.ArgumentParser(description='Plot metadata')
parser.add_argument('-i', '--input_table', type=Path, required=True, help='Input metadata file')
parser.add_argument('-o', '--output', type=Path, required=True, help='Output directory')
args = parser.parse_args()

if not args.input_table.exists():
    raise FileNotFoundError(f'{args.input_table} does not exist')

meta = pl.read_csv(os.fspath(args.input_table), separator='\t',
                   new_columns=['Metrics',
                                'Values',
                                'Sample'])

# if Values columns is Str dtype then convert to_integer
if meta['Values'].dtype == pl.String:
    meta = meta.with_columns(
        pl.col('Values').str.to_integer(base=10, strict=False)
    ).drop_nulls().pivot(
        index='Sample', on='Metrics', values='Values').rename({
            'Hi-CContacts': 'Hi-C Contacts',
        }).drop(cs.matches('align'))
else:
    meta = meta.drop_nulls().pivot(
        index='Sample', on='Metrics', values='Values').rename({
            'Hi-CContacts': 'Hi-C Contacts',
        }).drop(cs.matches('align'))

meta.write_csv(os.path.join(args.output, 'meta.clean.csv'))  # Save cleaned metadata


