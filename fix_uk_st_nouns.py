#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import uklib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  head = None
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "uk-noun":
      gen = blib.fetch_param_chain(t, "3", "gen")
      if len(gen) == 1 and gen[0].endswith(u"і"):
        gen2 = gen[0][0:-1] + u"и"
        t.add("gen2", gen2, before="4")
    elif tn in ["uk-decl-noun", "uk-decl-noun-unc", "uk-decl-noun-pl"]:
      gensparam = 3 if tn == "uk-decl-noun" else 2
      gens = getparam(t, str(gensparam))
      if "," not in gens and gens.endswith(u"і"):
        gens += ", " + gens[0:-1] + u"и"
        t.add(str(gensparam), gens)
    if origt != str(t):
      notes.append(u"add alternative genitive singular to Ukrainian nouns ending in -сть")
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser(u"Add alternative genitive singular to Ukrainian nouns ending in -сть",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
