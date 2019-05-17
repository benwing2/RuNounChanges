#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Find places where accent b is likely missing.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if not re.search(ur"(ник|ок)([ -]|$)", pagetitle):
    return

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-noun-table":
      ut = unicode(t)
      if re.search(ur"ни́к(\||$)", ut) and "|b" not in ut:
        pagemsg("WARNING: Likely missing accent b: %s" % ut)
      if re.search(ur"о́к(\||$)", ut) and "*" in ut and "|b" not in ut:
        pagemsg("WARNING: Likely missing accent b: %s" % ut)

parser = blib.create_argparser(u"Find likely missing accent b")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian nouns"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
