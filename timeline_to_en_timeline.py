#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import uklib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  head = None
  last_lang = None
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["citation", "citations"]:
      last_lang = getparam(t, "1")
    if tn == "timeline":
      if last_lang == "en":
        blib.set_template_name(t, "en-timeline")
        notes.append("'timeline' -> 'en-timeline'")
      else:
        pagemsg("WARNING: Skipped due to not being on English citations page (last_lang=%s): %s" % (last_lang, str(t)))

  return str(parsed), notes

parser = blib.create_argparser(u"timeline -> en-timeline on English citation pages",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, default_refs=["Template:timeline"], edit=True)
