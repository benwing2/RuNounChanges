#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if " " in pagetitle:
    pagemsg("WARNING: Space in page title, skipping")
    return None, None
  if not pagetitle.endswith("ium"):
    pagemsg("Doesn't end in -ium, skipping")
    return None, None
  pagemsg("Processing")

  num_ndecl_templates = 0
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "la-ndecl":
      num_ndecl_templates += 1
      lemmaspec = getparam(t, "1")
      m = re.search("^(.*)<(.*)>$", lemmaspec)
      if not m:
        pagemsg("WARNING: Unable to parse lemma+spec %s, skipping: %s" % (
          lemmaspec, origt))
        continue
      lemma, spec = m.groups()
      if ".-ium" not in spec:
        spec += ".-ium"
        t.add("1", "%s<%s>" % (lemma, spec))
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("add .-ium to declension of Latin chemical element")
  if num_ndecl_templates > 1:
    pagemsg("WARNING: Saw multiple {{la-ndecl}} templates, some may not be elements")
    return None, None

  return str(parsed), notes

parser = blib.create_argparser("Add missing .-ium to Latin elements",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["la:Chemical elements"], edit=True)
