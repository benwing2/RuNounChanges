#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"List pages in category or references in Zaliznyak order")
parser.add_argument('--cat', help="Category to list")
parser.add_argument('--ref', help="References to list")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages = []
if args.cat:
  pages_to_list = blib.cat_articles(args.cat, start, end)
else:
  pages_to_list = blib.references(args.ref, start, end)
for i, page in pages_to_list:
  pages.append(str(page.title()))
for page in sorted(pages, key=lambda x:x[::-1]):
  msg(page)
