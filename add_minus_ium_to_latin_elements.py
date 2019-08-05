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

  notes = []

  if " " in pagetitle:
    pagemsg("WARNING: Space in page title, skipping")
    return None, None
  if not pagetitle.endswith("ium"):
    pagemsg("Doesn't end in -ium, skipping")
    return None, None
  pagemsg("Processing")

  num_ndecl_templates = 0
  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn == "la-ndecl":
      num_ndecl_templates += 1
      lemmaspec = getparam(t, "1")
      m = re.search("^(.*)<(.*)>$", lemmaspec)
      if not m:
        pagemsg("WARNING: Unable to parse lemma+spec %s, skipping: %s" % (
          lemmaspec, origt))
        continue
      lemma, spec = m.groups()
      if ".-ium" not in spec:
        spec += ".-ium"
        t.add("1", "%s<%s>" % (lemma, spec))
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
        notes.append("add .-ium to declension of Latin chemical element")
  if num_ndecl_templates > 1:
    pagemsg("WARNING: Saw multiple {{la-ndecl}} templates, some may not be elements")
    return None, None

  return unicode(parsed), notes

parser = blib.create_argparser("Add missing .-ium to Latin elements")
parser.add_argument("--pagefile", help="List of pages to process.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pagefile:
  pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
  for i, page in blib.iter_items(pages, start, end):
    blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save,
      verbose=args.verbose, diff=args.diff)
else:
  for cat in ["la:Chemical elements"]:
    for i, page in blib.cat_articles(cat, start, end):
      blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose,
        diff=args.diff)
