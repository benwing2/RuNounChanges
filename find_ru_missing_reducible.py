#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Find places where a reducible * notation is likely missing in Russian nouns.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not re.search(r"(ник|ок|ка)([ -]|$)", pagetitle):
    return

  cons = u"[бцдфгчйклмнпрствшхзжщ]"
  if (pagetitle.endswith(u"ство") or pagetitle.endswith(u"ёнок") or re.search(u"[шжчщ]онок$", pagetitle) or (
      not re.search(cons + u"[кц][оаяеёыи]$", pagetitle) and
      not re.search(cons + cons + u"[оаяеёыи]$", pagetitle) and
      # not re.search(u"[оеё]" + cons + "$", pagetitle) and # but too many false positives
      not re.search(u"[оеё][кц]$", pagetitle)
     )):
    return
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "ru-noun-table" and "*" not in str(t):
      pagemsg("WARNING: Likely incorrectly-declined reducible: %s" % str(t))

parser = blib.create_argparser("Find places where reduciible * notation is likely missing in Russian noun declensions",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian nouns"])
