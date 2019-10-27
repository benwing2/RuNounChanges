#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Purge (null-save) pages in category or references",
  include_pagefile=True)
parser.add_argument('--ignore-non-mainspace', help="Ignore pages not in the mainspace",
    action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def process_page(page, index):
  global args
  if args.ignore_non_mainspace and ':' in unicode(page.title()):
    return
  # msg("Page %s %s: Null-saving" % (index, unicode(page.title())))
  page.save(comment="null save")

blib.do_pagefile_cats_refs(args, start, end, process_page)
