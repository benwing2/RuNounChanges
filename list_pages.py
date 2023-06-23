#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser("List pages, lemmas and/or non-lemmas", include_pagefile=True)
parser.add_argument('--namespace', help="List all pages in namespace")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.namespace:
  for i, page in blib.iter_items(site.allpages(
    start=start if isinstance(start, str) else '!', namespace=args.namespace,
    filterredir=False), start, end):
      msg("Page %s %s: Processing" % (i, str(page.title())))
else:
  def process_page(page, index):
    msg("Page %s %s: Processing" % (index, str(page.title())))
  blib.do_pagefile_cats_refs(args, start, end, process_page)
