#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Go through all Russian lemmas looking for headwords with secondary stress in them.

import pywikibot, re, sys, argparse
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
  return GR in unicodedata.normalize("NFD", str(text))

def output_heads_seen(overall=False):
  if overall:
    dic = overall_head_count
    msg("Overall templates seen:")
  else:
    dic = cat_head_count
    msg("Templates seen per category:")
  for head, count in sorted(dic.items(), key=lambda x:-x[1]):
    msg("  %s = %s" % (head, count))

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  parsed = blib.parse_text(text)
  found_page_head = False
  for t in parsed.filter_templates():
    found_this_head = False
    tn = tname(t)
    if tn in ru_normal_head_templates:
      heads = blib.fetch_param_chain(t, "1", "head")
      for head in heads:
        if has_secondary_stress(head):
          pagemsg("Found secondarily stressed head %s in %s" % (head,
            str(t)))
    elif tn == "head" and getparam(t, "1") == "ru":
      heads = blib.fetch_param_chain(t, "head", "head")
      for head in heads:
        if has_secondary_stress(head):
          pagemsg("Found secondarily stressed head %s in %s" % (head,
            str(t)))
    elif tn in ["ru-noun+", "ru-proper noun+", "ru-noun-table", "ru-noun-old"]:
      per_word_objs = runounlib.split_noun_decl_arg_sets(t, pagemsg)
      for per_word in per_word_objs:
        for arg_set in per_word:
          if has_secondary_stress(arg_set[1]):
            pagemsg("Found secondarily stressed head %s in %s" % (
              arg_set[1], str(t)))
    elif tn == "ru-decl-adj":
      head = getparam(t, "1")
      if has_secondary_stress(head):
        pagemsg("Found secondarily stressed head %s in %s" % (head,
          str(t)))

parser = blib.create_argparser("Find Russian terms with secondary stress in the headword",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian lemmas", "Russian non-lemma forms"])
