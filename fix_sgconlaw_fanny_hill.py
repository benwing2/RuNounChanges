#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert {{quote-Fanny Hill|part=2|[passage]}} → {{RQ:Cleland Fanny Hill|passage=[passage]}}.

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
    if tname(t) == "quote-Fanny Hill":
      origt = str(t)
      t.name = "RQ:Cleland Fanny Hill"
      rmparam(t, "part")
      if getparam(t, "1"):
        t.add("passage", getparam(t, "1"))
        rmparam(t, "1")
      notes.append("Replace {{quote-Fanny Hill}} with {{RQ:Cleland Fanny Hill}}")
      newt = str(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Convert {{quote-Fanny Hill}} to {{RQ:Cleland Fanny Hill}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.references("Template:quote-Fanny Hill", start, end):
  blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
