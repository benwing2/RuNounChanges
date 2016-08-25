#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)

  found_audio = False
  for t in parsed.filter_templates():
    if unicode(t.name) == "audio" and getparam(t, "lang") == "ru":
      found_audio = True
      break
  if found_audio:
    new_text = re.sub(r"\n*\[\[Category:Russian terms with audio links]]\n*", "\n\n", text)
    if new_text != text:
      comment = "Remove redundant [[:Category:Russian terms with audio links]]"
      if save:
        pagemsg("Saving with comment = %s" % comment)
        page.text = new_text
        page.save(comment=comment)
      else:
        pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Remove redundant audio-link categories")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.cat_articles("Russian terms with audio links", start, end):
  process_page(i, page, args.save, args.verbose)
