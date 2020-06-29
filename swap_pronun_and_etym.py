#!/usr/bin/env python
# -*- coding: utf-8 -*-

from collections import defaultdict
import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import find_regex

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  newtext = re.sub("^(===Pronunciation===\n.*?\n)(===Etymology===\n.*?\n)==",
      r"\2\1==", text, 0, re.S | re.M)
  if not newtext.endswith("\n"):
    newtext += "\n"
  pagemsg("-------- begin text ---------\n%s-------- end text --------" % newtext)

parser = blib.create_argparser("Put Etymology before Pronunciation",
    include_pagefile=True)
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = codecs.open(args.direcfile, "r", "utf-8")

pagename_and_text = find_regex.yield_text_from_find_regex(lines, args.verbose)
for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
    get_name=lambda x:x[0]):
  process_text_on_page(index, pagename, text)
