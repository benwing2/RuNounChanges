#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose, do_noun):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

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

parser = blib.create_argparser("Remove redundant 'Russian nouns' category")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in ["ru-noun", "ru-noun+"]:
  temppage = "Template:" + template
  msg("Processing %s" % temppage)
  for i, page in blib.references(temppage, start, end):
    process_page(i, page, args.save, args.verbose, do_noun=True)
for template in ["ru-proper noun", "ru-proper noun+"]:
  temppage = "Template:" + template
  msg("Processing %s" % temppage)
  for i, page in blib.references(temppage, start, end):
    process_page(i, page, args.save, args.verbose, do_noun=False)
