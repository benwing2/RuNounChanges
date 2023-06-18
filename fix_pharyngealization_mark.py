#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Correct use of U+02C1 pharyngealization mark to U+02E4.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  def frob(t, param):
    val = getparam(t, param)
    if val:
      newval = val.replace(u"\u02C1", u"\u02E4")
      if newval != val:
        t.add(param, newval)

  for t in parsed.filter_templates():
    origt = str(t)
    if tname(t) == "IPAchar":
      frob(t, "1")
    elif tname(t) == "IPA":
      if getparam(t, "lang"):
        firstparam = 1
      else:
        firstparam = 2
      for i in range(firstparam, 20):
        frob(t, str(i))
    newt = str(t)
    if origt != newt:
      notes.append("Correct use of U+02C1 pharyngealization mark to U+02E4")
      pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Correct use of U+02C1 pharyngealization mark to U+02E4",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
