#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  origtext = text

  retval = blib.find_modifiable_lang_section(text, "Japanese", pagemsg, force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_latin = retval

  notes = []

  newsecbody = re.sub("^====Compounds====$", "====Derived terms====", secbody, 0, re.M)
  if newsecbody != secbody:
    notes.append("Compounds -> Derived terms in Japanese section (see [[Wiktionary:Grease pit/2019/September#Requesting bot help]])")
    secbody = newsecbody

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in range(1, len(subsections), 2):
    if subsections[k] == "====Derived terms====\n":
      endk = k + 2
      while endk < len(subsections) and (
          re.search("^====(Synonyms|Antonyms)====\n$", subsections[endk])):
        endk += 2
      if endk > k + 2:
        subsections = (
          subsections[0:k] + subsections[k + 2:endk] +
          subsections[k:k + 2] + subsections[endk:]
        )
        notes.append("reorder Derived terms after Synonyms/Antonyms")

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Compounds -> Derived terms in Japanese section and reorder after Synonyms/Antonyms",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
