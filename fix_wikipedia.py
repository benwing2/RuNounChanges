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
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = unicode(t)
    if unicode(t.name) == "wikipedia":
      val = getparam(t, "1")
      newval = rulib.remove_accents(val)
      if val != newval:
        pagemsg("Removing accents from 1= in {{wikipedia|...}}")
        notes.append("remove accents from 1= in {{wikipedia|...}}")
        t.add("1", newval)
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return unicode(parsed), notes

parser = blib.create_argparser(u"Remove accents from 1= in {{wikipedia|...}}",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
