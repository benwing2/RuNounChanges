#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

french_head_templates = [
  "fr-abbr",
  "fr-adj",
  "fr-adv",
  "fr-diacritical mark",
  "fr-intj",
  "fr-noun",
  "fr-phrase",
  "fr-prefix",
  "fr-prep",
  "fr-prep phrase",
  "fr-pron",
  "fr-proper noun",
  "fr-punctuation mark",
  "fr-verb",
]

french_head_templates_1_not_head = [
  "fr-adj",
  "fr-noun",
  "fr-proper noun",
]

def process_page(page, index, parsed):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn in french_head_templates:
      if getparam(t, "head"):
        rmparam(t, "head")
        notes.append("remove redundant head= from {{%s}}" % tn)
      if tn not in french_head_templates_1_not_head and getparam(t, "1"):
        rmparam(t, "1")
        notes.append("remove redundant 1= from {{%s}}" % tn)
      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Remove redundant head params from French headwords",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:tracking/fr-headword/redundant-head"])
