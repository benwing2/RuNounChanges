#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Convert "literally X" expressions in the definition of a proverb into etymologies.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
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

      m = re.search(r'\A(.*)^(# .*\]\])[^a-zA-Z0-9\[\]\n]*(?:gloss)?[^a-zA-Z0-9\[\]\n]*literally[^a-zA-Z0-9\[\]\n]*([a-zA-Z0-9\[\]][^\n]*[a-zA-Z0-9\[\]])[^a-zA-Z0-9\[\]\n]*$(.*)\Z',
          sections[j], re.M | re.S)
      if m:
        pagemsg("Found defn '%s', literally '%s'" % (m.group(2), m.group(3)))
        if "\n===Etymology===\n" in sections[j]:
          pagemsg("WARNING: Found Etymology section already, not doing anything")
        else:
          sections[j] = '\n===Etymology===\nLiterally, "%s".\n%s%s%s' % (m.group(3), m.group(1), m.group(2), m.group(4))
          notes.append("Move literal meaning '%s' to etymology" % m.group(3))

  return "".join(sections), notes

parser = blib.create_argparser('Convert "literally X" expressions in the definition of a proverb into etymologies',
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian proverbs"])
