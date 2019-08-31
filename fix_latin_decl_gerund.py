#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  for t in parsed.filter_templates():
    if tname(t) == "la-decl-gerund":
      stem = getparam(t, "1")
      if stem and not stem.endswith("um"):
        origt = unicode(t)
        t.add("1", stem + "um")
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
        notes.append("modify {{la-decl-gerund}} param 1 from %s to %sum" % (
          stem, stem))
  return unicode(parsed), notes

parser = blib.create_argparser("Fix calls to {{la-decl-gerund}} to include final -um",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_refs=["Template:la-decl-gerund"], edit=True)
