#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Go through all the French terms we can find and remove redundant head=.

import pywikibot, re, sys, codecs, argparse
import unicodedata

import blib
from blib import getparam, rmparam, msg, site

fr_head_or_1_templates = ["fr-verb", "fr-adv", "fr-phrase",
  "fr-intj", "fr-prep"]

fr_head_only_templates = ["fr-noun", "fr-proper noun", "fr-proper-noun",
  "fr-adj", "fr-adj-form", "fr-abbr", "fr-diacritical mark",
  "fr-past participle", "fr-prefix", "fr-pron",
  "fr-punctuation mark", "fr-suffix", "fr-verb form", "fr-verb-form"]

fr_head_templates = fr_head_or_1_templates + fr_head_only_templates

exclude_punc_chars = u"-־׳״'.·*[]"
punc_chars = "".join("\\" + unichr(i) for i in range(sys.maxunicode)
    if unicodedata.category(unichr(i)).startswith('P') and
    unichr(i) not in exclude_punc_chars)

def link_text(text):
  words = re.split("([" + punc_chars + r"\s]+)", text)
  linked_words = [("[[" + word + "]]"
    if (i % 2) == 0 and word and "[" not in word and "]" not in word else word)
    for i, word in enumerate(words)]
  return "".join(linked_words)

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  text = unicode(page.text)

  def check_bad_head(text, arg):
    canontext = re.sub(u"[׳’]", "'", blib.remove_links(text))
    canonpagetitle = re.sub(u"[׳’]", "'", pagetitle)
    if canontext != canonpagetitle:
      pagemsg("WARNING: Canonicalized %s=%s not same as canonicalized page title %s (orig %s=%s)" %
          (arg, canontext, canonpagetitle, arg, text))

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = unicode(t)
    name = unicode(t.name)
    if name in fr_head_templates:
      head = getparam(t, "head")
      if head:
        linked_pagetitle = link_text(pagetitle)
        linked_head = link_text(head)
        if linked_pagetitle == linked_head:
          pagemsg("Removing redundant head=%s" % head)
          rmparam(t, "head")
          notes.append("remove redundant head= from {{%s}}" % name)
        else:
          pagemsg("Not removing non-redundant head=%s" % head)
          check_bad_head(head, "head")
    if name in fr_head_or_1_templates:
      head = getparam(t, "1")
      if head:
        linked_pagetitle = link_text(pagetitle)
        linked_head = link_text(head)
        if linked_pagetitle == linked_head:
          pagemsg("Removing redundant 1=%s" % head)
          rmparam(t, "1")
          notes.append("remove redundant 1= from {{%s}}" % name)
        else:
          pagemsg("Not removing non-redundant 1=%s" % head)
          check_bad_head(head, "1")

    newt = unicode(t)
    if origt != newt:
      pagemsg("Replacing %s with %s" % (origt, newt))

  return unicode(parsed), notes

parser = blib.create_argparser("Remove redundant head= from French terms",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["French lemmas"],
  #default_cats=["French lemmas", "French non-lemma forms"],)
