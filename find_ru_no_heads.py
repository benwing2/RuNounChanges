#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Go through all the terms we can find looking for pages that are
# missing a headword declaration.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

ru_normal_head_templates = ["ru-noun", "ru-proper noun", "ru-verb", "ru-adj",
  "ru-adv", "ru-phrase", "ru-noun form", "ru-diacritical mark"]
ru_special_head_templates = ["ru-noun+", "ru-proper noun+", "ru-noun-alt-ё",
  "ru-proper noun-alt-ё", "ru-adj-alt-ё", "ru-verb-alt-ё", "ru-pos-alt-ё"]
ru_head_templates = ru_normal_head_templates + ru_special_head_templates
ru_heads_to_warn_about = ["abbreviation", "acronym", "initialism", "idiom",
    "phrase", "adverb", "adjective", "verb", "noun", "proper noun"]

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
    if tname in ru_head_templates:
      headname = tname
      found_this_head = True
    elif tname == "head" and getparam(t, "1") == "ru":
      headtype = getparam(t, "2")
      headname = "head|ru|%s" % headtype
      if headtype in ru_heads_to_warn_about:
        pagemsg("WARNING: Found %s" % headname)
      found_this_head = True
    if found_this_head:
      cat_head_count[headname] = cat_head_count.get(headname, 0) + 1
      overall_head_count[headname] = overall_head_count.get(headname, 0) + 1
      found_page_head = True
  if not found_page_head:
    pagemsg("WARNING: No head")
  if index % 100 == 0:
    output_heads_seen()

parser = blib.create_argparser("Find Russian terms without a proper headword line")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian nouns", "Russian proper nouns", "Russian pronouns", "Russian determiners", "Russian adjectives", "Russian verbs", "Russian participles", "Russian adverbs", "Russian prepositions", "Russian conjunctions", "Russian interjections", "Russian idioms", "Russian phrases", "Russian abbreviations", "Russian acronyms", "Russian initialisms", "Russian noun forms", "Russian proper noun forms", "Russian pronoun forms", "Russian determiner forms", "Russian verb forms", "Russian adjective forms", "Russian participle forms"]:
  cat_head_count = {}
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
  output_heads_seen()
output_heads_seen(overall=True)
