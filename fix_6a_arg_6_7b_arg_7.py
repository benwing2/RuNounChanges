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
      if conjtype.startswith("6a"):
        param6 = getparam(t, "6")
        if param6:
          rmparam(t, "6")
          if not getparam(t, "5"):
            rmparam(t, "5")
          for i in xrange(1, 4):
            if not t.has(str(i)):
              t.add(str(i), "")
          t.add("4", param6)
          notes.append("move type 6a arg6 -> arg4")
      if conjtype.startswith("7b"):
        param7 = getparam(t, "7")
        if param7:
          rmparam(t, "7")
          for i in xrange(1, 6):
            if not t.has(str(i)):
              t.add(str(i), "")
          t.add("6", param7)
          notes.append("move type 7b arg7 -> arg6")
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

parser = blib.create_argparser(u"Fix up class 6a arg 6 -> 4, class 7b arg 7 -> 6")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for vclass in ["6a", "7b"]:
  for i, page in blib.references("Template:tracking/ru-verb/conj-%s" % vclass, start, end):
    process_page(i, page, args.save, args.verbose)
