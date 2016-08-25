#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Use past_adv_part_short=- instead of past_adv_part_short=

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-conj-7a", "ru-conj-7b"]:
      if t.has("past_adv_part_short") and getparam(t, "past_adv_part_short") == "":
        notes.append("set past_adv_part_short=-")
        origt = unicode(t)
        t.add("past_adv_part_short", "-")
        pagemsg("Replacing %s with %s" % (origt, unicode(t)))
      if t.has("past_actv_part") and getparam(t, "past_actv_part") == "":
        notes.append("set past_actv_part=-")
        origt = unicode(t)
        t.add("past_actv_part", "-")
        pagemsg("Replacing %s with %s" % (origt, unicode(t)))

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

  if not notes:
    pagemsg("WARNING: No changes")

parser = blib.create_argparser(u"Fix past_adv_part_short to use dash instead of blank")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.references("Template:tracking/ru-verb/different-conj", start, end):
  process_page(i, page, args.save, args.verbose)
