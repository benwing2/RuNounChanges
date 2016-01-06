#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Find places where ru-verb is missing or its aspect(s) don't agree with the
# aspect(s) in ru-conj-*.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  headword_aspects = set()
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-verb":
      headword_aspects = set()
      aspect = getparam(t, "2")
      if aspect in ["pf", "impf"]:
        headword_aspects.add(aspect)
      elif aspect == "both":
        headword_aspects.add("pf")
        headword_aspects.add("impf")
      elif aspect == "?":
        pagemsg("WARNING: Found aspect '?'")
      else:
        pagemsg("WARNING: Found bad aspect value '%s' in ru-verb" % aspect)
    elif tname.startswith("ru-conj-") and tname != "ru-conj-verb-see":
      aspect = re.sub("-.*", "", getparam(t, "1"))
      if aspect not in ["pf", "impf"]:
        pagemsg("WARNING: Found bad aspect value '%s' in ru-conj-*" %
            getparam(t, "1"))
      else:
        if not headword_aspects:
          pagemsg("WARNING: No ru-verb preceding ru-conj-*: %s" % unicode(t))
        elif aspect not in headword_aspects:
          pagemsg("WARNING: ru-conj-* aspect %s not in ru-verb aspect %s" %
              (aspect, ",".join(headword_aspects)))

parser = blib.create_argparser(u"Find incorrect verb aspects")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for category in ["Russian verbs"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
