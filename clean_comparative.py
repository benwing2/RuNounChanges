#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

is_lemma_templates = [
  "comparative of",
  "en-comparative of",
  "superlative of",
  "en-superlative of",
]

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in is_lemma_templates:
      if t.has("is lemma"):
        notes.append("Remove is lemma= from {{%s}}" % tn)
        rmparam(t, "is lemma")
      if t.has("is_lemma"):
        notes.append("Remove is_lemma= from {{%s}}" % tn)
        rmparam(t, "is_lemma")

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Remove is lemma= and is_lemma= from comparative/superlative templates",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats = ["comparative of with is lemma", "superlative of with is lemma"])
