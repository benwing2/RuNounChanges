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

def process_page(index, page, save, verbose, do_noun):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  text = unicode(page.text)
  parsed = blib.parse(page)

  cat = do_noun and "nouns" or "proper nouns"
  new_text = re.sub(r"\n\n\n*\[\[Category:Russian %s]]\n\n\n*" % cat, "\n\n", text)
  new_text = re.sub(r"\[\[Category:Russian %s]]\n" % cat, "", new_text)
  if new_text != text:
    comment = "Remove redundant [[:Category:Russian %s]]" % cat
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

for template in ["ru-noun", "ru-noun+"]:
  temppage = "Template:" + template
  msg("Processing %s" % temppage)
  for i, page in blib.references(temppage, start, end):
    if args.verbose:
      msg("Page %s %s: Processing" % (i, unicode(page.title())))
    process_page(i, page, args.save, args.verbose, do_noun=True)
for template in ["ru-proper noun", "ru-proper noun+"]:
  temppage = "Template:" + template
  msg("Processing %s" % temppage)
  for i, page in blib.references(temppage, start, end):
    if args.verbose:
      msg("Page %s %s: Processing" % (i, unicode(page.title())))
    process_page(i, page, args.save, args.verbose, do_noun=False)
