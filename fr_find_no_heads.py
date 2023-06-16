#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Go through all the French terms we can find looking for pages that are
# missing a headword declaration.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

fr_head_templates = ["fr-noun", "fr-proper noun", "fr-proper-noun",
  "fr-verb", "fr-adj", "fr-adv", "fr-phrase", "fr-adj form", "fr-adj-form",
  "fr-abbr", "fr-diacritical mark", "fr-intj", "fr-letter",
  "fr-past participle", "fr-prefix", "fr-prep", "fr-pron",
  "fr-punctuation mark", "fr-suffix", "fr-verb form", "fr-verb-form"]
fr_heads_to_warn_about = ["abbreviation", "acronym", "initialism", "idiom",
    "phrase", "adverb", "adjective", "adjective form", "verb", "noun",
    "proper noun", "prefix", "suffix", "interjection", "diacritical mark",
    "letter", "past participle", "preposition", "pronoun", "punctuation mark"]

overall_head_count = {}
cat_head_count = {}

def output_heads_seen(overall=False):
  if overall:
    dic = overall_head_count
    msg("Overall templates seen:")
  else:
    dic = cat_head_count
    msg("Templates seen per category:")
  for head, count in sorted(dic.items(), key=lambda x:-x[1]):
    msg("  %s = %s" % (head, count))

def process_page(index, page, save, verbose):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse(page)
  found_page_head = False
  for t in parsed.filter_templates():
    found_this_head = False
    tname = str(t.name)
    if tname in fr_head_templates:
      headname = tname
      found_this_head = True
    elif tname == "head" and getparam(t, "1") == "fr":
      headtype = getparam(t, "2")
      headname = "head|fr|%s" % headtype
      if headtype in fr_heads_to_warn_about:
        pagemsg("WARNING: Found %s" % str(t))
      found_this_head = True
    if found_this_head:
      cat_head_count[headname] = cat_head_count.get(headname, 0) + 1
      overall_head_count[headname] = overall_head_count.get(headname, 0) + 1
      found_page_head = True
  if not found_page_head:
    pagemsg("WARNING: No head")
  if index % 100 == 0:
    output_heads_seen()

parser = blib.create_argparser("Find French terms without a proper headword line")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["French nouns", "French proper nouns", "French pronouns", "French determiners", "French adjectives", "French verbs", "French participles", "French adverbs", "French prepositions", "French conjunctions", "French interjections", "French idioms", "French phrases", "French abbreviations", "French acronyms", "French initialisms", "French noun forms", "French proper noun forms", "French pronoun forms", "French determiner forms", "French verb forms", "French adjective forms", "French participle forms", "French proverbs", "French prefixes", "French suffixes", "French diacritical marks", "French punctuation marks"]:
  cat_head_count = {}
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
  output_heads_seen()
output_heads_seen(overall=True)
