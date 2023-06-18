#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  text = str(page.text)
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn == "head" and getparam(t, "1") == "ang" and getparam(t, "2") in ["adjective", "adjectives"]:
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "head"]:
          pagemsg("WARNING: head|ang|adjective with extra params: %s" % str(t))
          break
      else:
        # no break
        blib.set_template_name(t, "ang-adj")
        rmparam(t, "1")
        rmparam(t, "2")
        notes.append("convert {{head|ang|adjective}} into {{ang-adj}}")
    elif tn == "ang-adj":
      if getparam(t, "2"):
        t.add("1", "")
        notes.append("remove unneeded 1= from {{ang-adj}}")
      else:
        param1 = getparam(t, "1")
        if param1:
          t.add("1", "")
          t.add("2", param1)
          notes.append("move 1= to 2= in {{ang-adj}}")
      param4 = getparam(t, "4")
      if param4:
        rmparam(t, "4")
        if not getparam(t, "1"):
          t.add("1", "")
        if not getparam(t, "2"):
          t.add("2", "")
        t.add("3", param4)
        notes.append("move 4= to 3= in {{ang-adj}}")
    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))
  return parsed, notes

parser = blib.create_argparser("Fix Old English adjective headwords to new format",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Old English adjectives"], edit=1)
