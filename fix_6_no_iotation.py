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
    if unicode(t.name) in ["ru-conj"]:
      if re.search(r"^6[ac]", param1):
        if getparam(t, "no_iotation"):
          rmparam(t, "no_iotation")
          if param1.startswith("6a"):
            notes.append(u"6a + no_iotation -> 6°a")
          else:
            notes.append(u"6c + no_iotation -> 6°c")
          t.add("1", re.sub("^6", u"6°", param1))
      elif re.search(r"^6b", param1):
        notes.append(u"6b -> 6°b")
        t.add("1", re.sub("^6", u"6°", param1))
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

parser = blib.create_argparser(u"Fix up class-6 no-iotation verbs")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for i, page in blib.cat_articles("Russian class 6 verbs", start, end):
  process_page(i, page, args.save, args.verbose)
