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
    if unicode(t.name) == "ru-adj":
      comps = blib.fetch_param_chain(t, "2", "comp")
      newcomps = []
      for comp in comps:
        if re.search(u"е́?й$", comp):
          regcomp = re.sub(u"(е́?)й$", ur"\1е", comp)
          if regcomp in newcomps:
            pagemsg("Skipping informal form %s" % comp)
            notes.append("remove informal comparative %s" % comp)
          else:
            pagemsg("WARNING: Found informal form %s without corresponding regular form")
            newcomps.append(comp)
        else:
          newcomps.append(comp)
      if comps != newcomps:
        blib.set_param_chain(t, newcomps, "2", "comp")
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

parser = blib.create_argparser(u"Remove informal comparatives from adjectives when regular comparative present")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian adjectives"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
