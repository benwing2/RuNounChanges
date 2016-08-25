#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"List pages, lemmas and/or non-lemmas")
parser.add_argument('--cats', default="lemmas", help="Categories to do (can be comma-separated list)")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in re.split(",", args.cats):
  cat = "Russian " + cat
  msg("Processing category: %s" % cat)
  for i, page in blib.cat_articles(cat, start, end):
    msg("Page %s %s: Processing" % (i, unicode(page.title())))
