#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace page")
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    decl = None
    if tn in [
      "hi-noun-c-m", "hi-noun-c-c",
      "hi-noun-a-m", "hi-noun-a-a",
      u"hi-noun-ā-m", u"hi-noun-ā-e",
      "hi-noun-i-m", "hi-noun-i-i",
      u"hi-noun-ī-m", u"hi-noun-ī-ī",
      "hi-noun-o-m",
      "hi-noun-u-m", "hi-noun-u-u",
      u"hi-noun-ū-m", u"hi-noun-ū-ū",
    ]:
      decl = "<M>"
    elif tn in [
      u"hi-noun-ā-ā-m", u"hi-noun-ā-ā",
    ]:
      decl = "<M.unmarked>"
    elif tn in [
      "hi-noun-c-f", u"hi-noun-c-ẽ",
      u"hi-noun-ā-f", u"hi-noun-ā-āẽ",
      "hi-noun-i-f", u"hi-noun-i-iyā̃",
      u"hi-noun-ī-f", u"hi-noun-ī-iyā̃",
      "hi-noun-u-f", u"hi-noun-u-uẽ",
      u"hi-noun-ū-f", u"hi-noun-ū-ūẽ",
    ]:
      decl = "<F>"
    elif tn in [
      u"hi-noun-iyā-f", u"hi-noun-iyā-iyā̃",
    ]:
      decl = "<F.iyā>"
    if decl:
      t.add("1", decl)
      rmparam(t, "2")
      blib.set_template_name(t, "hi-ndecl")
      notes.append("convert {{%s}} to {{hi-ndecl}}" % tn)
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser(u"Convert old Hindi noun declension templates to new ones",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_cats=["Hindi nouns", "Hindi numerals", "Hindi pronouns", "Hindi determiners"], edit=True, stdin=True)
