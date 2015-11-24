#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse(page)

  for t in parsed.filter_templates():
    if unicode(t.name) == "ru-decl-noun-z":
      FIXME

  comment = "Replace ru-decl-noun-z with ru-noun-table"
  if save:
    pagemsg("Saving with comment = %s" % comment)
    page.text = unicode(parsed)
    page.save(comment=comment)
  else:
    pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Convert ru-decl-noun-z into ru-noun-table")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for index, page in blib.references("Template:ru-decl-noun-z", start, end):
  process_page(index, page, args.save, args.verbose)
