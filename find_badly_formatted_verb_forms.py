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
  found_head_verb_form = False
  for t in parsed.filter_templates():
    if unicode(t.name) in ["inflection of"]:
      found_inflection_of = True
    if unicode(t.name) == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "verb form":
      found_head_verb_form = True

  if not found_head_verb_form or not found_inflection_of:
    # Find definition line
    foundrussian = False
    sections = re.split("(^==[^=]*==\n)", unicode(page.text), 0, re.M)

    for j in xrange(2, len(sections), 2):
      if sections[j-1] == "==Russian==\n":
        if foundrussian:
          pagemsg("WARNING: Found multiple Russian sections, skipping page")
          return
        foundrussian = True

        deflines = r"\n".join(re.findall(r"^(# .*)$", sections[j], re.M))

  if not found_head_verb_form:
    pagemsg("WARNING: No {{head|ru|verb form}}: %s" % deflines)
  if not found_inflection_of:
    pagemsg("WARNING: No 'inflection of': %s" % deflines)

parser = blib.create_argparser(u"Find badly formatted Russian verb forms")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for category in ["Russian verb forms"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
