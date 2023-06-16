#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

# List whether pages exist and if so, are redirects and/or contain a specific language.

def process_page(page, index):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  if not blib.safe_page_exists(page, pagemsg):
    outtext = "does not exist"
  else:
    text = blib.safe_page_text(page, pagemsg)
    if re.search("#redirect", text, re.I):
      outtext = "exists as redirect"
    elif args.lang:
      if "==%s==" % args.lang in text:
        outtext = "exists in %s" % args.lang
      else:
        outtext = "exists but not in %s" % args.lang
    else:
      outtext = "exists"
  pagemsg(outtext)

parser = blib.create_argparser(u"List whether pages exist", include_pagefile=True)
parser.add_argument("--lang", help="Indicate whether the page contains an entry for the specified language")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page)
