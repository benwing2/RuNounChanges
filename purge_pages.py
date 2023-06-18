#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site

parser = blib.create_argparser(u"Purge (null-save) pages in category or references",
  include_pagefile=True)
parser.add_argument('--ignore-non-mainspace', help="Ignore pages not in the mainspace",
    action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def process_page(page, index):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  if args.ignore_non_mainspace and ':' in pagetitle:
    return
  if not blib.safe_page_exists(page, pagemsg):
    pagemsg("WARNING: Page doesn't exist, null-saving it would create it")
    return
  # pagemsg("Null-saving")
  blib.safe_page_save(page, "null save", errandpagemsg)

blib.do_pagefile_cats_refs(args, start, end, process_page)
