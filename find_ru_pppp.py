#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Find Russian perfective verbs with explicit past passive participles

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    if str(t.name) in ["ru-conj", "ru-conj-old"] and getparam(t, "1").startswith("pf"):
      if tname == "ru-conj":
        tempcall = re.sub(r"\{\{ru-conj", "{{ru-generate-verb-forms", str(t))
      else:
        tempcall = re.sub(r"\{\{ru-conj-old", "{{ru-generate-verb-forms|old=y", str(t))
      result = expand_text(tempcall)
      if not result:
        pagemsg("WARNING: Error generating forms, skipping")
        continue
      args = blib.split_generate_args(result)
      for base in ["past_pasv_part", "ppp"]:
        for i in ["", "2", "3", "4", "5", "6", "7", "8", "9"]:
          val = getparam(t, base + i)
          if val and val != "-":
            val = re.sub("//.*", "", val)
            pagemsg("Found perfective past passive participle: %s" % val)

parser = blib.create_argparser(u"Find Russian perfective verbs with explicit past passive participles")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian verbs"]:
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
