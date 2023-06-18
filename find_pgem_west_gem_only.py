#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import find_regex

def process_page(page, index):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse(page)

  non_wgem = False
  wgem = []
  for t in parsed.filter_templates():
    if tname(t) in ["desc", "desctree"]:
      if getparam(t, "bor"):
        continue
      desc = getparam(t, "1")
      if desc in [
        "got", "gme-cgo", "non", "non-ogt", "non-own", "non-oen",
        "is", "fo", "nrn", "no", "nb", "nn", "sv", "da",
        "gmq-osw", "gwq-oda", "gmq-bot", "gmq-jmk", "gmq-scy", "gmq-gut", "ovd"
      ]:
        pagemsg("Saw non-West-Germanic descendant %s" % str(t))
        non_wgem = True
      else:
        wgem.append(desc)
  if not non_wgem:
    pagemsg("Saw no non-West-Germanic descendants but saw West-Germanic or non-Germanic descendants %s" %
        ",".join(wgem))

parser = blib.create_argparser("Find West-Germanic-only Proto-Germanic terms",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, default_cats=["Proto-Germanic lemmas"])
