#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from collections import defaultdict
import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  lines = re.split("\n", text)
  newlines = []
  langs_at_levels = {}
  kurdish_indent = None
  kurdish_borrowing = None
  for line in lines:
    thisline_lang = None
    m = re.search("^([*]+:*)", line)
    if m:
      thisline_indent = len(m.group(1))
      if kurdish_indent and thisline_indent <= kurdish_indent:
        kurdish_indent = None
      if "{{desc|" in line or "{{desctree|" in line:
        parsed = blib.parse_text(line)
        for t in parsed.filter_templates():
          tn = tname(t)
          if tn in ["desc", "desctree"]:
            thisline_lang = getparam(t, "1")
            if thisline_lang == "ku":
              if getparam(t, "2") != "-":
                pagemsg("WARNING: Saw real 'Kurdish' descendant rather than anchoring line: %s" % str(t))
                continue
              kurdish_indent = thisline_indent
              kurdish_borrowing = getparam(t, "bor")
              line, did_replace = blib.replace_in_text(line, str(t), "Kurdish:", pagemsg)
              notes.append("replace {{desc|ku}} with raw 'Kurdish:'")
            elif kurdish_indent and thisline_indent > kurdish_indent and kurdish_borrowing:
                t.add("bor", "1")
                line = str(parsed)
                notes.append("add bor=1 to Kurdish-language (%s) descendant" % thisline_lang)
    else:
      kurdish_indent = None
    newlines.append(line)
  newtext = "\n".join(newlines)
  return newtext, notes

parser = blib.create_argparser("Convert 'ku' to 'Kurdish:' in {{desc}} and propagate |bor=1 to children",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
