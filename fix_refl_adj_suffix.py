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

  if not pagetitle.endswith(u"ся"):
    return

  text = unicode(page.text)
  notes = []

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    origt = unicode(t)
    if unicode(t.name) in ["ru-decl-adj", "ru-adj-old"] and getparam(t, "suffix") == u"ся":
      lemma = getparam(t, "1")
      lemma = re.sub(",", u"ся,", lemma)
      lemma = re.sub("$", u"ся", lemma)
      t.add("1", lemma)
      rmparam(t, "suffix")
      notes.append(u"move suffix=ся to lemma")
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

parser = blib.create_argparser(u"Rewrite reflexive adjectival participle declensions involving suffix=ся to put suffix in the lemma")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in ["ru-decl-adj", "ru-adj-old"]:
  msg("Processing Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    process_page(i, page, args.save, args.verbose)
