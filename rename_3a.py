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

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = unicode(t)
    if unicode(t.name) in ["ru-conj"]:
      conjtype = getparam(t, "1")
      if conjtype.startswith("3a"):
        t.add("1", conjtype.replace("3a", "3olda"))
        notes.append("rename conj type 3a -> 3olda")
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  new_text = unicode(parsed)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Rename class 3a to 3olda")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.references("Template:tracking/ru-verb/conj-3a", start, end):
  process_page(i, page, args.save, args.verbose)
