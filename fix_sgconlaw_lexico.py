#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  for t in parsed.filter_templates():
    if tname(t) == "R:Lexico":
      origt = str(t)
      rmparam(t, "lang")
      entry_uk = getparam(t, "entry_uk")
      if entry_uk:
        t.add("entry", entry_uk, before="entry_uk")
      rmparam(t, "entry_uk")
      url_uk = getparam(t, "url_uk")
      if url_uk:
        t.add("url", url_uk, before="url_uk")
      rmparam(t, "url_uk")
      p4 = getparam(t, "4")
      if p4:
        t.add("text", p4, before="4")
      rmparam(t, "4")
      newt = str(t)
      if origt != newt:
        notes.append("Remove/rearrange params in {{R:Lexico}}")
        pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Remove/rearrange params in {{R:Lexico}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.references("Template:R:Lexico", start, end):
  blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
