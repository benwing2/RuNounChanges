#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Move text outside of {{RQ:RJfrs AmtrPqr}} inside, with some renaming of
# templates and args. Specifically, we replace:
#
# #* {{RQ:RJfrs AmtrPqr|II|071}}
# #*: Orion hit a rabbit once; [...]
#
# with:
#  
# #* {{RQ:Jefferies Amateur Poacher|chapter=II|passage=Orion hit a rabbit once; [...]}}

import pywikibot, re, sys, argparse
import mwparserfromhell as mw

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return

  text = str(page.text)
  notes = []

  newtext = text
  curtext = newtext

  newtext = re.sub(r"\{\{RQ:RJfrs AmtrPqr\|([^|]*?)(?:\|[^|]*?)?\}\}\n#+\*: (.*?)\n",
    r"{{RQ:Jefferies Amateur Poacher|chapter=\1|passage=\2}}\n", curtext)
  if curtext != newtext:
    notes.append("reformat {{RQ:RJfrs AmtrPqr}}")
    curtext = newtext

  return curtext, notes

if __name__ == "__main__":
  parser = blib.create_argparser("Reformat {{RQ:Brmnghm Gsmr}} and {{RQ:Fielding Tom Jones}}", include_pagefile=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_page,
      default_refs=["Template:RQ:RJfrs AmtrPqr"], edit=True)
