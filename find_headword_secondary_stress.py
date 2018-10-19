#!/usr/bin/env python
#coding: utf-8

#    find_headword_secondary_stress.py is free software: you can redistribute it and/or modify
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

# Go through all the lemmas looking for headwords with secondary stress in them.

import pywikibot, re, sys, codecs, argparse
import unicodedata

import blib
from blib import getparam, rmparam, tname, msg, site

import rulib
import runounlib

GR = u"\u0300" # grave =  ̀

ru_normal_head_templates = ["ru-noun", "ru-proper noun", "ru-verb", "ru-adj",
  "ru-adv", "ru-phrase", "ru-noun form", "ru-diacritical mark",
  u"ru-noun-alt-ё", u"ru-adj-alt-ё", u"ru-verb-alt-ё"]

overall_head_count = {}
cat_head_count = {}

def has_secondary_stress(text):
  return GR in unicodedata.normalize("NFD", unicode(text))

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
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  parsed = blib.parse(page)
  found_page_head = False
  for t in parsed.filter_templates():
    found_this_head = False
    if tname(t) in ru_normal_head_templates:
      heads = blib.fetch_param_chain(t, "1", "head")
      for head in heads:
        if has_secondary_stress(head):
          pagemsg("Found secondarily stressed head %s in %s" % (head,
            unicode(t)))
    elif tname(t) == "head" and getparam(t, "1") == "ru":
      heads = blib.fetch_param_chain(t, "head", "head")
      for head in heads:
        if has_secondary_stress(head):
          pagemsg("Found secondarily stressed head %s in %s" % (head,
            unicode(t)))
    elif tname(t) in ["ru-noun+", "ru-proper noun+", "ru-noun-table", "ru-noun-old"]:
      per_word_objs = runounlib.split_noun_decl_arg_sets(t, pagemsg)
      for per_word in per_word_objs:
        for arg_set in per_word:
          if has_secondary_stress(arg_set[1]):
            pagemsg("Found secondarily stressed head %s in %s" % (
              arg_set[1], unicode(t)))
    elif tname(t) == "ru-decl-adj":
      head = getparam(t, "1")
      if has_secondary_stress(head):
        pagemsg("Found secondarily stressed head %s in %s" % (head,
          unicode(t)))

parser = blib.create_argparser(u"Find Russian terms without a proper headword line")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian lemmas", "Russian non-lemma forms"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
