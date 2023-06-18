#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Move text outside of certain RQ: templates inside the templates.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site

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
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    if str(t.name) == "RQ:Wodehouse Offing":
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
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

if __name__ == "__main__":
  parser = blib.create_argparser("Fix params in RQ:Wodehouse Offing templates",
    include_pagefile=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_refs=["Template:RQ:Wodehouse Offing"],
    # FIXME: formerly had includelinks=True on call to blib.references();
    # doesn't exist any more
  )
