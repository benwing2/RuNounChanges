#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Replace title= with work= in cite-web, if work= doesn't already exist.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site

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
        pagemsg(("Replacing %s with %s" % (origt, str(t))).replace("\n", r"\n"))
  return str(parsed), notes

if __name__ == "__main__":
  parser = blib.create_argparser("Fix title and entry in a couple reference templates",
    include_pagefile=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_refs=["Template:cite-web"],
    # FIXME: formerly had includelinks=True on call to blib.references();
    # doesn't exist any more
  )
