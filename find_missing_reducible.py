#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Find places where a reducible * notation is likely missing.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  cons = u"[бцдфгчйклмнпрствшхзжщ]"
  if not re.search(cons + u"[кц][оаяеыи]$", pagetitle) and not re.search(u"[ое][кц]$", pagetitle):
    return
  text = unicode(page.text)
  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-noun-table" and "*" not in unicode(t):
      pagemsg("WARNING: Likely incorrectly-declined reducible: %s" % unicode(t))

parser = blib.create_argparser(u"Find incorrect verb aspects")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for category in ["Russian nouns"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
