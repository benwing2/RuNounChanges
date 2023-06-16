#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

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
  pagemsg("Processing")

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "la-ndecl":
      lemmaspec = getparam(t, "1")
      m = re.search("^(.*)<(.*)>$", lemmaspec)
      if not m:
        pagemsg("WARNING: Unable to parse lemma+spec %s, skipping: %s" % (
          lemmaspec, origt))
        continue
      lemma, spec = m.groups()
      if "/" in lemma:
        base, stem2 = lemma.split("/")
        if stem2 == re.sub(u"gō$", "gin", base):
          stem2 = ""
      else:
        base = lemma
        stem2 = base + "n"
      if not base.endswith(u"gō"):
        pagemsg(u"WARNING: Base %s doesn't end in -gō, skipping: %s" % (
          base, origt))
        continue
      if stem2:
        newlemma = "%s/%s" % (base, stem2)
      else:
        newlemma = base
      t.add("1", "%s<%s>" % (newlemma, spec))
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append(u"convert 3rd-declension -gō term according to new default stem -gin in {{la-ndecl}}")

  return str(parsed), notes

parser = blib.create_argparser(u"Fix Latin 3rd-decl -gō nouns to default to stem in -gin",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
