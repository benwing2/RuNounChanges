#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

AC = u"\u0301"
GR = u"\u0300"
SUB = u"\uFFFD"
def decompose_bulgarian(text):
    # need to decompose grave-accented еЕиИ
    text = text.replace(u"ѝ", u"и" + GR)
    text = text.replace(u"Ѝ", u"И" + GR)
    text = text.replace(u"ѐ", u"е" + GR)
    text = text.replace(u"Ѐ", u"Е" + GR)
    return text

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  text = str(page.text)
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn == "bg-IPA":
      if not getparam(t, "old"):
        continue
      pron = getparam(t, "1")
      if pron:
        pron = decompose_bulgarian(pron)
        pron = pron.replace(AC, SUB)
        pron = pron.replace(GR, AC)
        pron = pron.replace(SUB, GR)
        t.add("1", pron)
      rmparam(t, "old")
      notes.append("convert {{bg-IPA}} pronunciation to new style (flip acute and grave) and remove old=1")
    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))
  return parsed, notes

parser = blib.create_argparser("Fix {{bg-IPA}} to new format",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, default_refs=["Template:bg-IPA"], edit=1)
