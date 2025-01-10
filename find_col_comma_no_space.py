#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not re.search(r"\{\{ *(col[0-9]*|col-auto|der[0-9]|rel[0-9])(-u)? *\|", text):
    return

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if re.search("^(col[0-9]*|col-auto|der[0-9]|rel[0-9])(-u)?$", tn):
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if re.search(args.regex, pv):
          pagemsg("Found %s=%s: %s" % (pn, pv, str(t)))

parser = blib.create_argparser("Find column templates with comma not followed by space, or other regex",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--regex", default=",[^ ]", help="Regex to search for.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
