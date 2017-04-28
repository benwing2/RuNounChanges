#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Replace title= with entry= in a couple of reference templates, and strip
# final periods from entry= in the same templates.

import pywikibot, re, sys, codecs, argparse
import mwparserfromhell as mw

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site

import rulib

replace_templates = [
    "R:MED Online", "R:Reference-meta"
]

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
  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    origt = unicode(t)
    if tname.strip() in replace_templates:
      changed = False
      title = getparam(t, "title")
      if title:
        t.get("title").name = "entry"
        notes.append("title -> entry in {{%s}}" % tname.strip())
        changed = True
      entry = getparam(t, "entry")
      if changed:
        pagemsg(("Replacing %s with %s" % (origt, unicode(t))).replace("\n", r"\n"))
  newtext = unicode(parsed)
  for tname in replace_templates:
    curtext = newtext
    newtext = re.sub(r"(\{\{%s\|[^{}]*\}\})\." % tname, r"\1", curtext)
    if curtext != newtext:
      notes.append("remove final period after {{%s}}" % tname)
      pagemsg(("Replacing %s with %s" % (curtext, newtext)).replace("\n", r"\n"))
  if text != newtext:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, newtext))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

if __name__ == "__main__":
  parser = blib.create_argparser("Fix title and entry in a couple reference templates")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  for template in replace_templates:
    msg("Processing references to Template:%s" % template)
    errmsg("Processing references to Template:%s" % template)
    for i, page in blib.references("Template:%s" % template, start, end,
        includelinks=True):
      process_page(i, page, args.save, args.verbose)
