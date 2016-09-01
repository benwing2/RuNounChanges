#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  notes = []

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    origt = unicode(t)
    if unicode(t.name) in ["ru-conj", "ru-conj-old"]:
      verbtype = getparam(t, "2")
      if verbtype in ["pf", "pf-intr", "pf-refl",
          "pf-impers", "pf-intr-impers", "pf-refl-impers",
          "impf", "impf-intr", "impf-refl",
          "impf-impers", "impf-intr-impers", "impf-refl-impers"]:
        conjtype = getparam(t, "1")
        t.add("2", conjtype)
        t.add("1", verbtype)
        notes.append("move verb type from arg 2 to arg 1")
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

parser = blib.create_argparser(u"Move verb type from arg 2 to arg 1")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.cat_articles("Russian verbs", start, end):
  process_page(i, page, args.save, args.verbose)
