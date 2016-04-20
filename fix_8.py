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
    param1 = getparam(t, "1")
    if unicode(t.name) in ["ru-conj"] and re.search(r"^8[ab]", param1):
      past_m = getparam(t, "past_m")
      if past_m:
        rmparam(t, "past_m")
        stem = getparam(t, "3")
        if stem == past_m:
          pagemsg("Stem %s and past_m same" % stem)
          notes.append("remove redundant past_m %s" % past_m)
        elif (param1.startswith("8b") and not param1.startswith("8b/") and
            ru.make_unstressed(past_m) == stem):
          pagemsg("Class 8b/b and stem %s is unstressed version of past_m %s, replacing stem with past_m" % (
            stem, past_m))
          t.add("3", past_m)
          notes.append("moving past_m %s to arg 3" % past_m)
        else:
          pagemsg("Stem %s and past_m %s are different, putting past_m in param 5" % (
            stem, past_m))
          t.add("5", past_m)
          notes.append("moving past_m %s to arg 5" % past_m)
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

parser = blib.create_argparser(u"Fix up class-8 arguments")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for i, page in blib.cat_articles("Russian class 8 verbs", start, end):
  process_page(i, page, args.save, args.verbose)
