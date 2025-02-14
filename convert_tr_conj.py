#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param).strip()
    if tn == "tr-conj/old":
      stem = getp("1")
      v1 = getp("2")
      aorist = getp("3")
      v2 = getp("4")
      td = getp("5")
      if not stem:
        pagemsg("WARNING: No stem, skipping: %s" % origt)
        continue
      if len(v1) != 1 or len(v2) != 1:
        pagemsg("WARNING: Vowel v1=%s or v2=%s isn't the right length, skipping: %s" % (v1, v2, origt))
        continue
      num_vowels = len(re.sub("[^aeıioöuü]", "", stem))
      if num_vowels == 1 and v2 in "ıiuü":
        param1 = v2
      else:
        param1 = None
      del t.params[:]
      blib.set_template_name(t, "tr-conj")
      if param1:
        t.add("1", param1)
    elif tn == "tr-conj-*tmek":
      del t.params[:]
      blib.set_template_name(t, "tr-conj")
      t.add("1", "d")
    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))
      notes.append("replace %s with new module-based %s" % (origt, str(t)))

  text = str(parsed)

  return text, notes

parser = blib.create_argparser("Convert old-style {{tr-conj*}} calls to new module-based {{tr-conj}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
