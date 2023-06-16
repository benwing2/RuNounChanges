#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Replace title= with entry= in a couple of reference templates, and strip
# final periods from entry= in the same templates.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site

replace_templates = [
    "R:MED Online", "R:Reference-meta"
]

def process_page(page, index, parsed):
  pagetitle = str(page.title())
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

  text = str(page.text)
  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tname = str(t.name)
    origt = str(t)
    if tname.strip() in replace_templates:
      changed = False
      title = getparam(t, "title")
      if title:
        t.get("title").name = "entry"
        notes.append("title -> entry in {{%s}}" % tname.strip())
        changed = True
      entry = getparam(t, "entry")
      if changed:
        pagemsg(("Replacing %s with %s" % (origt, str(t))).replace("\n", r"\n"))
  newtext = str(parsed)
  for tname in replace_templates:
    curtext = newtext
    newtext = re.sub(r"(\{\{%s\|[^{}]*\}\})\." % tname, r"\1", curtext)
    if curtext != newtext:
      notes.append("remove final period after {{%s}}" % tname)
      pagemsg(("Replacing %s with %s" % (curtext, newtext)).replace("\n", r"\n"))
  return newtext, notes

if __name__ == "__main__":
  parser = blib.create_argparser("Fix title and entry in a couple reference templates",
    include_pagefile=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_refs=["Template:%s" % template for template in replace_templates],
    # FIXME: formerly had includelinks=True on call to blib.references();
    # doesn't exist any more
  )
