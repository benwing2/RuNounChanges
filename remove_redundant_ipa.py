#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "es-IPA" not in text and "fr-IPA" not in text and "it-IPA" not in text:
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn in ["es-IPA", "fr-IPA", "it-IPA"]:
      must_continue = False
      for i in range(2, 11):
        if getparam(t, str(i)):
          pagemsg("Template has %s=, not touching: %s" % (i, origt))
          must_continue = True
          break
      if must_continue:
        continue
      par1 = getparam(t, "1")
      if par1 == pagetitle:
        rmparam(t, "1")
        notes.append("remove redundant 1=%s from {{%s}}" % (par1, tn))
      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Remove redundant 1= from Romance *-IPA",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:es-IPA", "Template:fr-IPA", "Template:it-IPA"])
