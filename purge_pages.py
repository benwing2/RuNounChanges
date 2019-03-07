#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Purge (null-save) pages in category or references")
parser.add_argument('--cat', help="Category to purge")
parser.add_argument('--ref', help="References to purge")
parser.add_argument('--ignore-non-mainspace', help="Ignore pages not in the mainspace",
    action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages = []
if args.cat:
  pages_to_list = blib.cat_articles(args.cat, start, end)
else:
  pages_to_list = blib.references(args.ref, start, end)
for i, page in pages_to_list:
  if args.ignore_non_mainspace and ':' in unicode(page.title()):
    continue
  # msg("Page %s %s: Null-saving" % (i, unicode(page.title())))
  page.save(comment="null save")
