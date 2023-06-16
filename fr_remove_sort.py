#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Go through all the French terms we can find and remove sort=.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

fr_head_templates = ["fr-noun", "fr-proper noun", "fr-proper-noun",
  "fr-verb", "fr-adj", "fr-adv", "fr-phrase", "fr-adj form", "fr-adj-form",
  "fr-abbr", "fr-diacritical mark", "fr-intj", "fr-letter",
  "fr-past participle", "fr-prefix", "fr-prep", "fr-pron",
  "fr-punctuation mark", "fr-suffix", "fr-verb form", "fr-verb-form"]

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  text = str(page.text)

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    name = str(t.name)
    if name in fr_head_templates:
      rmparam(t, "sort")
    newt = str(t)
    if origt != newt:
      pagemsg("Replacing %s with %s" % (origt, newt))
      notes.append("remove sort= from {{%s}}" % name)

  return str(parsed), notes

parser = blib.create_argparser("Remove sort= from French terms",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["French lemmas", "French non-lemma forms"])
