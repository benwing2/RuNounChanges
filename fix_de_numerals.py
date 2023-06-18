#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  text = str(page.text)
  text = re.sub(r"\n(===+)Adjective(===+)\n\{\{head\|de\|adjective form\}\}", "\n" + r"\1Numeral\2" + "\n{{head|de|numeral form}}",
      text)
  notes.append("change headword from adjective form to numeral form")
  return text, notes

parser = blib.create_argparser("Change ordinal numeral form headwords from adjective to numeral")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

endings = ["en", "er", "em", "es"]

for index, page in blib.cat_articles("German ordinal numbers", start, end):
  pagetitle = str(page.title())
  if not pagetitle.endswith("e"):
    continue
  for ending in endings:
    page = pywikibot.Page(site, pagetitle[:-1] + ending)
    if page.exists():
      blib.do_edit(page, index, process_page, save=args.save, verbose=args.verbose)
