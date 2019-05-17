#!/usr/bin/env python
#coding: utf-8

#    find_no_heads.py is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Go through all the terms we can find looking for pages that are
# missing a headword declaration.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

ru_normal_head_templates = ["ru-noun", "ru-proper noun", "ru-verb", "ru-adj",
  "ru-adv", "ru-phrase", "ru-noun form", "ru-diacritical mark"]
ru_special_head_templates = ["ru-noun+", "ru-proper noun+", u"ru-noun-alt-ё",
  u"ru-proper noun-alt-ё", u"ru-adj-alt-ё", u"ru-verb-alt-ё", u"ru-pos-alt-ё"]
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
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse(page)
  found_page_head = False
  for t in parsed.filter_templates():
    found_this_head = False
    tname = unicode(t.name)
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

parser = blib.create_argparser(u"Find Russian terms without a proper headword line")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian nouns", "Russian proper nouns", "Russian pronouns", "Russian determiners", "Russian adjectives", "Russian verbs", "Russian participles", "Russian adverbs", "Russian prepositions", "Russian conjunctions", "Russian interjections", "Russian idioms", "Russian phrases", "Russian abbreviations", "Russian acronyms", "Russian initialisms", "Russian noun forms", "Russian proper noun forms", "Russian pronoun forms", "Russian determiner forms", "Russian verb forms", "Russian adjective forms", "Russian participle forms"]:
  cat_head_count = {}
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
  output_heads_seen()
output_heads_seen(overall=True)
