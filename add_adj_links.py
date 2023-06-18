#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if "-" not in pagetitle:
    pagemsg("Skipping, no dash in title")
    return

  text = str(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = str(t)

    if str(t.name) in ["ru-IPA"]:
      pron = getparam(t, "1") or getparam(t, "phon")
      if not re.search("[̀ѐЀѝЍ]", pron):
        pagemsg("WARNING: No secondary accent in pron %s" % pron)

    if str(t.name) in ["ru-adj"]:
      head = getparam(t, "1")
      if head and "[[" not in head:
        def add_links(m):
          prefix = m.group(1)
          if re.search("[гкх]о$", prefix):
            first = prefix[:-1] + "ий"
          else:
            first = prefix[:-1] + "ый"
          return "[[%s|%s]]-[[%s]]" % (rulib.remove_accents(first), prefix, m.group(2))
        t.add("1", re.sub("^(.*?о)-([^-]*)$", add_links, head))
      notes.append("add links to two-part adjective")
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser("Add links to two-part adjectives",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian adjectives"])
