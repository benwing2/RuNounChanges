#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import rulib

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  russian = blib.find_lang_section_from_text(text, "Russian", pagemsg)
  if not russian:
    pagemsg("Couldn't find Russian section for %s" % pagetitle)
    return

  subsections = re.split("(^===+[^=\n]+===+\n)", russian, 0, re.M)
  # Go through each subsection in turn, looking for subsection
  # matching the POS with an appropriate headword template whose
  # head matches the inflected form
  for j in range(2, len(subsections), 2):
    if "==Etymology" in subsections[j - 1]:
      parsed = blib.parse_text(subsections[j])
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "diminutive of":
          pagemsg("WARNING: Found diminutive-of in etymology: %s" % str(t))

parser = blib.create_argparser("Find uses of {{diminutive of}} in Russian Etymology sections",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian diminutive nouns", "Russian diminutive adjectives"])
