#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  found_infl = False
  for t in parsed.filter_templates():
    tn = tname(t)
    if pos == "verbs" and tn.startswith("ang-conj"):
      pagemsg("Found verb conjugation: %s" % str(t))
      found_infl = True
    elif pos == "nouns" and tn.startswith("ang-decl-noun"):
      pagemsg("Found noun conjugation: %s" % str(t))
      found_infl = True
    elif pos == "adjectives" and tn.startswith("ang-decl-adj"):
      pagemsg("Found adjective conjugation: %s" % str(t))
      found_infl = True
  if not found_infl:
    pagemsg("WARNING: Couldn't find inflection template")

parser = blib.create_argparser("Find Old English terms without inflection",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Old English %s" % pos for pos in ["nouns", "verbs", "adjectives"])
