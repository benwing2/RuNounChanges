#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

site = pywikibot.Site()

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

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

parser = argparse.ArgumentParser(description="Remove redundant audio-link categories")
parser.add_argument('start', help="Starting page index", nargs="?")
parser.add_argument('end', help="Ending page index", nargs="?")
parser.add_argument('--save', action="store_true", help="Save results")
parser.add_argument('--verbose', action="store_true", help="More verbose output")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for i, page in blib.cat_articles("Russian terms with audio links", start, end):
  msg("Page %s %s: Processing" % (i, unicode(page.title())))
  process_page(i, page, args.save, args.verbose)
