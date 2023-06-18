#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Add accented forms to {{cardinalbox}} and {{ordinalbox}}.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  adjval = None
  numval = None
  for t in parsed.filter_templates():
    if str(t.name) == "ru-adj":
      adjval = blib.remove_links(getparam(t, "1"))
    if (str(t.name) == "head" and getparam(t, "1") == "ru" and
        getparam(t, "2") == "numeral"):
      numval = blib.remove_links(getparam(t, "head"))
  for t in parsed.filter_templates():
    origt = str(t)
    if str(t.name) == "ordinalbox" and getparam(t, "1") == "ru":
      if not adjval:
        pagemsg("WARNING: Can't find accented ordinal form")
      elif adjval != pagetitle:
        t.add("alt", adjval)
        notes.append("Add alt=%s to ordinalbox" % adjval)
    if str(t.name) == "cardinalbox" and getparam(t, "1") == "ru":
      if not numval:
        pagemsg("WARNING: Can't find accented cardinal form")
      elif numval != pagetitle:
        t.add("alt", numval)
        notes.append("Add alt=%s to cardinalbox" % numval)
      if "[[Category:Russian cardinal numbers]]" not in str(parsed):
        pagemsg("WARNING: Numeral not in [[Category:Russian cardinal numbers]]")
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Add accented forms to {{cardinalbox}} and {{ordinalbox}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.cat_articles("Russian ordinal numbers", start, end):
  blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
for i, page in blib.cat_articles("Russian numerals", start, end):
  blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
