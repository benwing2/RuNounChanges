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

  notes = []

  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    m = re.search("^==(.*)==\n$", sections[j - 1])
    assert m
    langname = m.group(1)
    if langname not in blib.languages_byCanonicalName:
      pagemsg("WARNING: Can't find language %s" % langname)
      continue
    langcode = blib.languages_byCanonicalName[langname]["code"]
    sections[j] = re.sub(r"\bLANGCODE\b", langcode, sections[j])
    notes.append("replace LANGCODE with %s" % langcode)

  newtext = "".join(sections)
  return newtext, notes

parser = blib.create_argparser("Replace LANGCODE with appropriate language code",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
