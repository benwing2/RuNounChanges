#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Find usexes with 'literally' in them")
parser.add_argument('--cats', default="Russian lemmas", help="Categories to do (can be comma-separated list)")
parser.add_argument('--refs', help="References to do (can be comma-separated list)")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def process_page(index, page, save, verbose):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if not page.exists():
    pagemsg("WARNING: Page doesn't exist")
    return

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return

  text = str(page.text)
  lines = text.split("\n")
  for line in lines:
    if re.search(r"\{\{(ru-ux|uxi?\|ru)\|.*[Ll]it(erally|\.)", line):
      pagemsg("Found literally with usex: %s" % line)
    elif re.search(r"\{\{(ru-ux|uxi?\|ru)\|.*\{\{(i|qualifier)\|", line):
      pagemsg("Found qualifier with usex: %s" % line)
    elif re.search(r"\{\{(i|qualifier)\|.*\{\{(ru-ux|uxi?\|ru)\|", line):
      pagemsg("Found qualifier with usex: %s" % line)
    elif re.search(r"\{\{(ru-ux|uxi?\|ru)\|.*\|ref=&#32;", line):
      pagemsg("Found ref=space with usex: %s" % line)

if args.refs:
  for ref in re.split(",", args.refs):
    msg("Processing references to: %s" % ref)
    for i, page in blib.references(ref, start, end):
      process_page(i, page, args.save, args.verbose)
else:
  for cat in re.split(",", args.cats):
    msg("Processing category: %s" % cat)
    for i, page in blib.cat_articles(cat, start, end):
      process_page(i, page, args.save, args.verbose)
