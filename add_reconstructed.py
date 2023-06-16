#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if blib.page_should_be_ignored(pagetitle):
    pagemsg("Skipping ignored page")
    return None, None

  notes = []

  text = str(page.text)
  if not re.search(r"\{\{reconstruct(ed|ion)\}\}", text):
    text = "{{reconstructed}}\n" + text
    notes.append("add missing {{reconstructed}} to Reconstruction: pages")
  elif re.search(r"\A\{\{reconstruct(ed|ion)\}\}\n", text):
    pass
  elif re.search(r"\A\{\{also\|.*?\}\}\n\{\{reconstruct(ed|ion)\}\}\n", text):
    pass
  elif re.search(r"\A\{\{reconstruct(ed|ion)\}\}", text):
    pagemsg("WARNING: Missing newline after initial {{reconstructed}}/{{reconstruction}}")
  else:
    pagemsg("WARNING: Page has {{reconstructed}}/{{reconstruction}} not at beginning: <%s>" % text)
  return text, notes

parser = blib.create_argparser("Add {{reconstructed}} to Reconstruction: pages where missing",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
