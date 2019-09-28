#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  notes = []

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    origt = unicode(t)
    if unicode(t.name) in ["ru-conj", "ru-conj-old"]:
      verbtype = getparam(t, "1")
      if verbtype == "pf-impers-refl":
        t.add("1", "pf-refl-impers")
        notes.append("pf-impers-refl -> pf-refl-impers")
      if verbtype == "impf-impers-refl":
        t.add("1", "impf-refl-impers")
        notes.append("impf-impers-refl -> impf-refl-impers")
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return unicode(parsed), notes

parser = blib.create_argparser(u"Change verb type *-impers-refl to *-refl-impers",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian verbs"])
