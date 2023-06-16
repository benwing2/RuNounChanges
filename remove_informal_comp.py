#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    if str(t.name) == "ru-adj":
      comps = blib.fetch_param_chain(t, "2", "comp")
      newcomps = []
      for comp in comps:
        if re.search(u"е́?й$", comp):
          regcomp = re.sub(u"(е́?)й$", ur"\1е", comp)
          if regcomp in newcomps:
            pagemsg("Skipping informal form %s" % comp)
            notes.append("remove informal comparative %s" % comp)
          else:
            pagemsg("WARNING: Found informal form %s without corresponding regular form")
            newcomps.append(comp)
        else:
          newcomps.append(comp)
      if comps != newcomps:
        blib.set_param_chain(t, newcomps, "2", "comp")
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser("Remove informal comparatives from adjectives when regular comparative present",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian adjectives"])
