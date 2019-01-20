#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Move text outside of certain RQ: templates inside the templates.

import pywikibot, re, sys, codecs, argparse
import mwparserfromhell as mw

import blib
from blib import getparam, rmparam, group_notes, msg, errmsg, site

import rulib

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if not page.exists():
    pagemsg("WARNING: Page doesn't exist")
    return

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = unicode(t)
    if unicode(t.name) == "RQ:Wodehouse Offing":
      chapter = getparam(t, "1")
      passage = getparam(t, "2")
      if chapter or passage:
        rmparam(t, "1")
        rmparam(t, "2")
        if chapter:
          t.add("chapter", chapter)
        if passage:
          t.add("passage", passage)
        notes.append("Fix params in RQ:Wodehouse Offing")
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  new_text = unicode(parsed)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    comment = "; ".join(group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

if __name__ == "__main__":
  parser = blib.create_argparser("Fix params in RQ:Wodehouse Offing templates")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  for template in ["RQ:Wodehouse Offing"]:
    msg("Processing references to Template:%s" % template)
    errmsg("Processing references to Template:%s" % template)
    for i, page in blib.references("Template:%s" % template, start, end,
        includelinks=True):
      process_page(i, page, args.save, args.verbose)
