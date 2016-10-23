#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Rearrange {{was wotd}} to go after ==English==.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  origtext = unicode(page.text)
  text = origtext
  text = re.sub(r"(\{\{was wotd\|.*?\}\}\n)(==English==\n)", r"\2\1", text)
  notes = ["put {{was wotd}} after ==English== per [[User:Smuconlaw]]"]

  if text != origtext:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (origtext, text))
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Remove adj= and shto= from ru-ux")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.references("Template:was wotd", start, end):
  process_page(i, page, args.save, args.verbose)
