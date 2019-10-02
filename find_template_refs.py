#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site, tname

def process_page(page, index):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  #if pagetitle.startswith("Template:"):
  pagemsg("Found one")

parser = blib.create_argparser("Find templates transcluding a given page")
parser.add_argument("--pages",
    help=u"""Comma-separated list of pages to check.""")
parser.add_argument("--pagefile",
    help=u"""File containing pages to check.""")
parser.add_argument("--redirects-only",
    help=u"""Only output redirects.""", action='store_true')
parser.add_argument("--table-of-uses", action='store_true',
    help=u"""Output in table_of_uses.py input format.""")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pages:
  pages = args.pages.split(",")
else:
  pages = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
  for pagename in pages:
    errmsg("Processing references to %s" % pagename)
    if not args.table_of_uses:
      msg("Processing references to %s" % pagename)
    aliases = []
    for i, page in blib.references(pagename, start, end, namespaces=[10], only_template_inclusion=False, filter_redirects=args.redirects_only):
      aliases.append(unicode(page.title()))
      if not args.table_of_uses:
        process_page(page, i)
    if args.table_of_uses:
      msg("%s%s" % (pagename.replace("Template:", ""),
        aliases and "," + ",".join(x.replace("Template:", "") for x in aliases) or ""))
