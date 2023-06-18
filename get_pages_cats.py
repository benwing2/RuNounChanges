#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

parser = blib.create_argparser("Get categories that a list of pages belongs to")
parser.add_argument("--direcfile", help="File of pages and extra info", required=True)
parser.add_argument("--cats", help="Categories to list for the pages in question", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

cats = args.cats.split(",")
cat_contents = {}
for cat in cats:
  cat_contents[cat] = set()
  for index, page in blib.cat_articles(cat):
    cat_contents[cat].add(str(page.title()))

for index, line in blib.yield_items_from_file(args.direcfile, include_original_lineno=True):
  page, extra_info = line.split(": ", 1)
  cats_seen = []
  for cat in cats:
    if page in cat_contents[cat]:
      cats_seen.append(cat)
  msg("* Page %s [[%s]]: %s: %s" % (index, page, extra_info, ",".join(cats_seen)))
