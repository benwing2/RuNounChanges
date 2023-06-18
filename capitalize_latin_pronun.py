#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("Skipping page with colon in pagetitle")
    return None, None

  notes = []

  for t in parsed.filter_templates():
    if tname(t) == "la-IPA":
      param1 = getparam(t, "1")
      if param1:
        origt = str(t)
        newparam1 = param1[0].upper() + param1[1:]
        if newparam1 != param1:
          t.add("1", newparam1)
          pagemsg("Replaced %s with %s" % (origt, str(t)))
          notes.append("capitalize %s in {{la-IPA}} to match page title" % param1)

  return str(parsed), notes

parser = blib.create_argparser("Capitalize {{la-IPA}} as appropriate for page title",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, default_refs=["Template:la-IPA"], edit=True,
    filter_pages=lambda pagetitle: pagetitle[0].isupper())
