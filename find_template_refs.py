#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

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
    help=u"""Comma-separated list of pages to check.""")
parser.add_argument("--redirects-only",
    help=u"""Only output redirects.""", action='store_true')
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pages:
  pages = args.pages.split(",")
else:
  pages = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
  for page in pages:
    msg("Processing references to %s" % page)
    for i, page in blib.references(page, start, end, namespaces=["Template"], only_template_inclusion=False, filter_redirects=args.redirects_only):
      process_page(page, i)
