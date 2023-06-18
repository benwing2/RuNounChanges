#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Find places where accent b is likely missing in Russian noun declensions.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not re.search(r"(ник|ок)([ -]|$)", pagetitle):
    return

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "ru-noun-table":
      ut = str(t)
      if re.search(r"ни́к(\||$)", ut) and "|b" not in ut:
        pagemsg("WARNING: Likely missing accent b: %s" % ut)
      if re.search(r"о́к(\||$)", ut) and "*" in ut and "|b" not in ut:
        pagemsg("WARNING: Likely missing accent b: %s" % ut)

parser = blib.create_argparser("Find places where accent b is likely missing in Russian noun declensions",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian nouns"])
