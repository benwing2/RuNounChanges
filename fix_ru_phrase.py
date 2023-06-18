#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Fix ru-phrase templates to use 1= instead of head=.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    if str(t.name) == "ru-phrase":
      if t.has("tr"):
        pagemsg("WARNING: Has tr=: %s" % str(t))
      if t.has("head"):
        if t.has("1"):
          pagemsg("WARNING: Has both head= and 1=: %s" % str(t))
        else:
          notes.append("ru-phrase: convert head= to 1=")
          origt = str(t)
          head = getparam(t, "head")
          rmparam(t, "head")
          tr = getparam(t, "tr")
          rmparam(t, "tr")
          t.add("1", head)
          if tr:
            t.add("tr", tr)
          pagemsg("Replacing %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Fix ru-phrase templates to use 1= instead of head=",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:ru-phrase"])
