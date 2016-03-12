#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"List pages in category in Zaliznyak order")
parser.add_argument('--cat', help="Category to list")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

pages = []
for i, page in blib.cat_articles(args.cat, start, end):
  pages.append(unicode(page.title()))
for page in sorted(pages, key=lambda x:x[::-1]):
  msg(page)
