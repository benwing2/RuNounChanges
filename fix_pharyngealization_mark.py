#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Correct use of U+02C1 pharyngealization mark to U+02E4.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  def frob(t, param):
    val = getparam(t, param)
    if val:
      newval = val.replace(u"\u02C1", u"\u02E4")
      if newval != val:
        t.add(param, newval)

  for t in parsed.filter_templates():
    origt = unicode(t)
    if tname(t) == "IPAchar":
      frob(t, "1")
    elif tname(t) == "IPA":
      if getparam(t, "lang"):
        firstparam = 1
      else:
        firstparam = 2
      for i in range(firstparam, 20):
        frob(t, str(i))
    newt = unicode(t)
    if origt != newt:
      notes.append("Correct use of U+02C1 pharyngealization mark to U+02E4")
      pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Correct use of U+02C1 pharyngealization mark to U+02E4")
parser.add_argument("--pagefile", help="List of pages to process.", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
for i, page in blib.iter_items(pages, start, end):
  blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save,
      verbose=args.verbose)
