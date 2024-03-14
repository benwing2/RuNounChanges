#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

conversions = [
  ("ɪ", "i"),
  ("i̞", "i"),
  ("ɨ", "i"),
  ("ɛ̃", "ɛ"),
  ("ɐ̠", "a"),
  ("ɐ", "a"),
  ("ä", "a"),
  ("ã", "a"),
  ("ɑ̝", "a"),
  ("ɑ", "a"),
  ("aː", "a"),
  ("ʊ", "u"),
]

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn == "IPA" and getp("1") == "scn":
      origt = str(t)
      for i in range(2, 10):
        pron = getp(str(i))
        newpron = pron
        if re.search("^/.*/$", pron):
          for fro, to in conversions:
            newpron = newpron.replace(fro, to)
          if newpron != pron:
            t.add(str(i), newpron)
            notes.append("canonicalize Sicilian phonemic pronun %s to %s" % (pron, newpron))
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Clean non-phonemic notation in Sicilian phonemic pronunciations",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_cats=["Sicilian terms with IPA pronunciation"])
