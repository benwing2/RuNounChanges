#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix up raw verb forms when possible, canonicalize existing 'conjugation of'
# to 'inflection of'

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

langs_to_codes = {}

def process_page(page, index, parsed):
  global args
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = unicode(page.text)
  notes = []

  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    m = re.search("^==(.*?)==\n", sections[j-1])
    lang = m.group(1)
    parsed = blib.parse_text(sections[j])
    for t in parsed.filter_templates():
      if unicode(t.name) == "audio" and not getparam(t, "lang"):
        origt = unicode(t)
        if lang in langs_to_codes:
          langcode = langs_to_codes[lang]
        else:
          langcode = expand_text("{{#invoke:languages/templates|getByCanonicalName|%s|getCode}}" % lang)
          if not langcode:
            pagemsg("WARNING: Unable to find code for lang %s" % lang)
            continue
          langs_to_codes[lang] = langcode
        t.add("lang", langcode)
        newt = unicode(t)
        if origt != newt:
          pagemsg("Replaced %s with %s" % (origt, newt))
    sections[j] = unicode(parsed)

  return "".join(sections), "add lang code to audio templates"

parser = blib.create_argparser(u"Add lang code to audio templates",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Language code missing/audio"])
