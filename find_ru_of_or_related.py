#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Find pages that need definitions among a set list (e.g. most frequent words).

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = str(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = str(page.text)
  notes = []

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      if re.search("[Oo]f or related", sections[j]):
        pagemsg("Found likely of-or-related")

parser = blib.create_argparser(u"Find pages that need definitions")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian adjectives"]:
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
