#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

is_lemma_templates = [
  "comparative of",
  "en-comparative of",
  "superlative of",
  "en-superlative of",
]

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn in is_lemma_templates:
      if t.has("is lemma"):
        notes.append("Remove is lemma= from {{%s}}" % tn)
        rmparam(t, "is lemma")
      if t.has("is_lemma"):
        notes.append("Remove is_lemma= from {{%s}}" % tn)
        rmparam(t, "is_lemma")

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Remove is lemma= and is_lemma= from comparative/superlative templates")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["comparative of with is lemma", "superlative of with is lemma"]:
  msg("Processing category '%s'" % category)
  for i, page in blib.cat_articles(category, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
