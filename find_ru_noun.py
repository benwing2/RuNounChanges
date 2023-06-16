#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = str(page.title())
  subpagetitle = re.sub(".*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  notes = []
  text = str(page.text)
  parsed = blib.parse(page)

  for t in parsed.filter_templates():
    if str(t.name) in ["ru-noun", "ru-proper noun"]:
      param3 = getparam(t, "3")
      if param3 == "-":
        pagemsg("Found indeclinable noun")
      elif "[[Category:Russian indeclinable nouns]]" in text:
        pagemsg("WARNING: Indeclinable noun but not marked in template")
      else:
        for tt in parsed.filter_templates():
          ttname = str(tt.name)
          if ttname == u"ru-noun-alt-ё":
            pagemsg(u"Found alternative ё spelling")
            break
          elif ttname == "misspelling of":
            pagemsg("Found misspelling of")
            break
          elif ttname == "ru-pre-reform":
            for ttt in parsed.filter_templates():
              if str(ttt.name) == "ru-noun-old":
                pagemsg("Found pre-reform word with ru-noun-old declension")
                break
            else:
              pagemsg("Found pre-reform word without ru-noun-old declension")
            break
        else:
          pagemsg("WARNING: Found declinable non-pre-reform noun")

parser = blib.create_argparser("Find cases of declined ru-noun uses")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.references("Template:ru-noun", start, end):
  process_page(i, page, args.save, args.verbose)
for i, page in blib.references("Template:ru-proper noun", start, end):
  process_page(i, page, args.save, args.verbose)
