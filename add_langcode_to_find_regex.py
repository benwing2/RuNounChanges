#!/usr/bin/env python
# -*- coding: utf-8 -*-

from collections import defaultdict
import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

blib.getData()

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    m = re.search("^==(.*)==\n$", sections[j - 1])
    assert m
    langname = m.group(1)
    if langname not in blib.languages_byCanonicalName:
      pagemsg("WARNING: Can't find language %s" % langname)
      continue
    langcode = blib.languages_byCanonicalName[langname]["code"]
    sections[j] = re.sub(r"\bLANGCODE\b", langcode, sections[j])

  newtext = "".join(sections)
  if not newtext.endswith("\n"):
    newtext += "\n"
  pagemsg("-------- begin text ---------\n%s-------- end text --------" % newtext)

parser = blib.create_argparser("Replace LANGCODE with appropriate language code",
    include_pagefile=True)
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = codecs.open(args.direcfile, "r", "utf-8")

pagename_and_text = blib.yield_text_from_find_regex(lines, args.verbose)
for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
    get_name=lambda x:x[0]):
  process_text_on_page(index, pagename, text)
