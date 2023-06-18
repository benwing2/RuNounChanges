#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  parsed = blib.parse(page)

  found_headword_template = False
  headword_templates = []
  found_invariant_headword_template = False
  found_decl_template = False
  for t in parsed.filter_templates():
    if str(t.name) in ["ru-noun", "ru-proper noun"]:
      found_headword_template = True
      if getparam(t, "3") == "-":
        found_invariant_headword_template = True
      else:
        headword_templates.append(str(t))
    if str(t.name) in ["ru-noun-table", "ru-decl-noun-see"]:
      found_decl_template = True
  if found_headword_template and not found_invariant_headword_template:
    if found_decl_template:
      pagemsg("Found old-style headword template(s) %s with decl" % ", ".join(headword_templates))
    else:
      pagemsg("Found old-style headword template(s) %s without decl" % ", ".join(headword_templates))

parser = blib.create_argparser("Find Russian nouns without declension")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

#for pos in ["nouns", "proper nouns"]:
#  Do multi-word nouns
#  tracking_page = "Template:tracking/ru-headword/space-in-headword/" + pos
#  msg("Processing references to %s" % tracking_page)
#  for index, page in blib.references(tracking_page, start, end):
#    process_page(index, page)
#  Do all nouns with {{ru-noun}} or {{ru-proper noun}}
for template in ["ru-noun", "ru-proper noun"]:
  for index, page in blib.references("Template:%s" % template, start, end):
    process_page(index, page)
