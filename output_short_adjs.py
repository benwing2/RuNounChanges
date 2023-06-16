#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse, codecs
import rulib
from collections import OrderedDict

parser = argparse.ArgumentParser(description="Output short adjectives in Wiktionary, ordered by frequency.")
parser.add_argument("--freq-adjs", help=u"""Adjectives ordered by frequency, without accents or ё.""",
    required=True)
parser.add_argument("--wiktionary-short-adjs",
    help=u"""Adjectives in Wiktionary with short forms, in alphabetical order.
Should be accented and with ё.""", required=True)
args = parser.parse_args()

short_adjs = OrderedDict((rulib.make_unstressed_ru(x), True) for x in blib.yield_items_from_file(args.wiktionary_short_adjs))
for line in blib.yield_items_from_file(args.freq_adjs):
  if line in short_adjs:
    print line.encode("utf-8")
    del short_adjs[line]
for line in short_adjs:
  print line.encode("utf-8")
