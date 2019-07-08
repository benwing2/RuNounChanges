#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "la-decl-2nd":
      stem = getparam(t, "1")
      if stem.endswith("i"):
        blib.set_template_name(t, "la-decl-2nd-ius")
        t.add("1", stem[:-1])
        notes.append("Fix noun in -ius to use {{la-decl-2nd-ius}}")
      else:
        pagemsg("WARNING: Found la-decl-2nd without stem in -i: %s" % unicode(t))
    elif tn == "la-decl-2nd-N":
      stem = getparam(t, "1")
      if stem.endswith("i"):
        blib.set_template_name(t, "la-decl-2nd-N-ium")
        t.add("1", stem[:-1])
        notes.append("Fix noun in -ium to use {{la-decl-2nd-N-ium}}")
      else:
        pagemsg("WARNING: Found la-decl-2nd-N without stem in -i: %s" % unicode(t))

  return unicode(parsed), notes

parser = blib.create_argparser("Fix Latin declensions of -ius/-ium nouns")
parser.add_argument("--pagefile", help="List of pages to process.", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
for i, page in blib.iter_items(pages, start, end):
  blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save,
      verbose=args.verbose, diff=args.diff)
