#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse, codecs
import rulib as ru
from collections import OrderedDict

parser = argparse.ArgumentParser(description="Output short adjectives in Wiktionary, ordered by frequency.")
parser.add_argument("--freq-adjs",
    help=u"""Adjectives ordered by frequency, without accents or ё.""")
parser.add_argument("--wiktionary-short-adjs",
    help=u"""Adjectives in Wiktionary with short forms, in alphabetical order.
Should be accented and with ё.""")
args = parser.parse_args()

short_adjs = OrderedDict((ru.make_unstressed(x.strip()), True) for x in codecs.open(args.wiktionary_short_adjs, "r", "utf-8"))
for line in codecs.open(args.freq_adjs, "r", "utf-8"):
  line = line.strip()
  if line in short_adjs:
    print line.encode("utf-8")
    del short_adjs[line]
for line in short_adjs:
  print line.encode("utf-8")
