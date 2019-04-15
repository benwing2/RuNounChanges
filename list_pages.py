#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"List pages, lemmas and/or non-lemmas")
parser.add_argument('--cats', help="Categories to do (can be comma-separated list)")
parser.add_argument('--recursive', help="In conjunction with --cats, recursively list pages in subcategories.",
  action="store_true")
parser.add_argument('--refs', help="References to do (can be comma-separated list)")
parser.add_argument('--namespace', help="List all pages in namespace")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.refs:
  for ref in re.split(",", args.refs):
    msg("Processing references to: %s" % ref)
    for i, page in blib.references(ref, start, end):
      msg("Page %s %s: Processing" % (i, unicode(page.title())))
elif args.cats:
  for cat in re.split(",", args.cats):
    msg("Processing category: %s" % cat)
    for i, page in blib.cat_articles(cat, start, end):
      msg("Page %s %s: Processing" % (i, unicode(page.title())))
    if args.recursive:
      for i, subcat in blib.cat_subcats(cat, start, end, recurse=True):
        msg("Processing subcategory: %s" % unicode(subcat.title()))
        for j, page in blib.cat_articles(subcat, start, end):
          msg("Page %s %s: Processing" % (j, unicode(page.title())))

elif args.namespace:
  ns = args.namespace
  if re.search('^[0-9]+$', ns):
    ns = int(ns)
  for i, page in blib.iter_items(site.allpages(
    start=start if isinstance(start, basestring) else '!', namespace=ns,
    filterredir=False), start, end):
      msg("Page %s %s: Processing" % (i, unicode(page.title())))
