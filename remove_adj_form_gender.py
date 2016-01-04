#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Remove gender from adjective forms.

import pywikibot, re, sys, codecs, argparse
from collections import Counter

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = unicode(page.text)
  notes = []

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      # Remove gender from adjective forms
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if unicode(t.name) == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "adjective form":
          origt = unicode(t)
          rmparam(t, "g")
          rmparam(t, "g2")
          rmparam(t, "g3")
          rmparam(t, "g4")
          newt = unicode(t)
          if origt != newt:
            pagemsg("Replaced %s with %s" % (origt, newt))
            notes.append("remove gender from adjective forms")
      sections[j] = unicode(parsed)
  new_text = "".join(sections)

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

parser = blib.create_argparser(u"Add 'inflection of' for raw short adjective forms and canonicalize existing 'inflection of'")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for category in ["Russian adjective forms"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
