#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Remove adj= and shto= from ru-ux.

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
    if str(t.name) == "ru-ux":
      origt = str(t)
      if t.has("adj"):
        pagemsg("Removing adj=")
        notes.append("remove adj= from ru-ux")
        rmparam(t, "adj")
      if t.has("shto"):
        pagemsg("Removing shto=")
        notes.append("remove shto= from ru-ux")
        rmparam(t, "shto")
      newt = str(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser("Remove adj= and shto= from ru-ux",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:ru-ux"])
