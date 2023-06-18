#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Find pages that need definitions among a set list (e.g. most frequent words).

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser("Find pages that need definitions",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = set(blib.yield_items_from_file(args.pagefile))
for i, page in blib.cat_articles("Russian entries needing definition", start, end):
  pagetitle = page.title()
  if pagetitle in lines:
    msg("* Page %s [[%s]]" % (i, pagetitle))
