#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      found_headword_template = False
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        tname = unicode(t.name)
        if tname == "ru-adj" or (tname == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "adjective form"):
          found_headword_template = True
      if not found_headword_template and "===Adjective===" in sections[j]:
        pagemsg("WARNING: Missing adj headword template")

parser = blib.create_argparser("Find missing adjective headwords")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in ["Russian adjectives", "Russian adjective forms", "Russian lemmas", "Russian non-lemma forms"]:
  msg("Processing category %s" % cat)
  for index, page in blib.cat_articles(cat, start, end):
    process_page(index, page)
