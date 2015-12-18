#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Use past_adv_part_short=- instead of past_adv_part_short=

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  found_inflection_of = False
  for t in parsed.filter_templates():
    if unicode(t.name) in ["inflection of"]:
      found_inflection_of = True
  if not found_inflection_of:
    pagemsg("WARNING: No 'inflection of'")

parser = blib.create_argparser(u"Find badly formatted Russian noun forms")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for category in ["Russian noun forms"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
