#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"List pages, lemmas and/or non-lemmas")
parser.add_argument('--cats', default="Russian lemmas", help="Categories to do (can be comma-separated list)")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def list_category(cat):
  for i, page in blib.cat_articles(cat, start, end):
    msg("Page %s %s: Processing page" % (i, str(page.title())))
  for i, page in blib.cat_subcats(cat, start, end):
    msg("Page %s %s: Processing subcategory" % (i, str(page.title())))
    list_category(re.sub("^Category:", "", str(page.title())))
    
for cat in re.split(",", args.cats):
  msg("Processing category: %s" % cat)
  list_category(cat)
