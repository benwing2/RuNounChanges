#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

# Hindi vowel diacritics; don't display nicely on their own
M = u"\u0901"
N = u"\u0902"
AA = u"\u093e"

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  noun_head_template = None
  noun_head_template_maybe_unmarked = False
  saw_ndecl = False
  saw_place = False
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn == "hi-noun":
      noun_head_template = None
      noun_head_template_maybe_unmarked = False
      saw_ndecl = False
      saw_place = False
    elif tn == "hi-proper noun":
      noun_head_template = t
      head = getparam(t, "head") or pagetitle
      if "m" in getparam(t, "g") and re.search("[" + AA + u"आ][" + M + N + "]?$", head):
        noun_head_template_maybe_unmarked = True
      else:
        noun_head_template_maybe_unmarked = False
      saw_ndecl = False
      saw_place = False
    elif tn == "place":
      saw_place = True
      if not noun_head_template:
        pagemsg("WARNING: Saw {{place}} without preceding {{hi-proper noun}}")
    elif tn == "hi-ndecl":
      saw_ndecl = True
      decl = getparam(t, "1")
      if "unmarked" not in decl and noun_head_template_maybe_unmarked:
        pagemsg(u"WARNING: Saw proper noun ending in -ā or -ā̃, probably needing 'unmarked': %s" % str(t))
      if saw_place and "sg" not in decl:
        pagemsg("WARNING: Saw proper noun with {{place}} but without 'sg' in declension template: %s" % str(t))

parser = blib.create_argparser("Check for proper noun needing 'unmarked' in declension",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, default_cats=["Hindi lemmas"], stdin=True)
