#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import find_regex

# Hindi vowel diacritics; don't display nicely on their own
M = u"\u0901"
N = u"\u0902"
AA = u"\u093e"

def process_page_text(index, pagetitle, text):
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
    origt = unicode(t)
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
        pagemsg(u"WARNING: Saw proper noun ending in -ā or -ā̃, probably needing 'unmarked': %s" % unicode(t))
      if saw_place and "sg" not in decl:
        pagemsg("WARNING: Saw proper noun with {{place}} but without 'sg' in declension template: %s" % unicode(t))

  return unicode(parsed), notes

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  text = unicode(page.text)
  return process_page_text(index, pagetitle, text)

def process_find_regex_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  newtext, notes = process_page_text(index, pagetitle, text)

parser = blib.create_argparser("Check for proper noun needing 'unmarked' in declension",
  include_pagefile=True)
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.direcfile:
  lines = codecs.open(args.direcfile, "r", "utf-8")

  pagename_and_text = find_regex.yield_text_from_find_regex(lines, args.verbose)
  for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
      get_name=lambda x:x[0]):
    process_find_regex_page(index, pagename, text)
else:
  blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_cats=["Hindi lemmas"])
