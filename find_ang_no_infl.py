#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(index, page, cat):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  parsed = blib.parse(page)

  found_infl = False
  for t in parsed.filter_templates():
    tn = tname(t)
    if pos == "verbs" and tn.startswith("ang-conj"):
      pagemsg("Found verb conjugation: %s" % unicode(t))
      found_infl = True
    elif pos == "nouns" and tn.startswith("ang-decl-noun"):
      pagemsg("Found noun conjugation: %s" % unicode(t))
      found_infl = True
    elif pos == "adjectives" and tn.startswith("ang-decl-adj"):
      pagemsg("Found adjective conjugation: %s" % unicode(t))
      found_infl = True
  if not found_infl:
    pagemsg("WARNING: Couldn't find inflection template")

parser = blib.create_argparser("Find Old English terms without inflection")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for pos in ["nouns", "verbs", "adjectives"]:
  for index, page in blib.cat_articles("Old English %s" % pos, start, end):
    process_page(index, page, pos)
