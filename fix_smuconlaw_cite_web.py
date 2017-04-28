#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Replace title= with work= in cite-web, if work= doesn't already exist.

import pywikibot, re, sys, codecs, argparse
import mwparserfromhell as mw

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site

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
  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    origt = unicode(t)
    if tname.strip() == "cite-web":
      changed = False
      if t.has("title") and not t.has("work"):
        t.get("title").name = "work"
        changed = True
        notes.append("title -> work in {{%s}}" % tname.strip())
      if t.has("trans_work") and not t.has("trans-work"):
        t.get("trans_work").name = "trans-work"
        changed = True
      if t.has("trans_title") and not t.has("trans-work"):
        t.get("trans_title").name = "trans-work"
        changed = True
        notes.append("trans_title -> trans-work in {{%s}}" % tname.strip())
      if t.has("trans-title") and not t.has("trans-work"):
        t.get("trans-title").name = "trans-work"
        changed = True
        notes.append("trans-title -> trans-work in {{%s}}" % tname.strip())
      if changed:
        pagemsg(("Replacing %s with %s" % (origt, unicode(t))).replace("\n", r"\n"))
  newtext = unicode(parsed)
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

  for template in ["cite-web"]:
    msg("Processing references to Template:%s" % template)
    errmsg("Processing references to Template:%s" % template)
    for i, page in blib.references("Template:%s" % template, start, end,
        includelinks=True):
      process_page(i, page, args.save, args.verbose)
