#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("WARNING: Script no longer applies and would need fixing up")
  return

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = unicode(t)
    if unicode(t.name) in ["ru-conj"]:
      conjtype = getparam(t, "1")
      if conjtype.startswith("6a"):
        param6 = getparam(t, "6")
        if param6:
          rmparam(t, "6")
          if not getparam(t, "5"):
            rmparam(t, "5")
          for i in range(1, 4):
            if not t.has(str(i)):
              t.add(str(i), "")
          t.add("4", param6)
          notes.append("move type 6a arg6 -> arg4")
      if conjtype.startswith("7b"):
        param7 = getparam(t, "7")
        if param7:
          rmparam(t, "7")
          for i in range(1, 6):
            if not t.has(str(i)):
              t.add(str(i), "")
          t.add("6", param7)
          notes.append("move type 7b arg7 -> arg6")
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return unicode(parsed), notes

parser = blib.create_argparser("Fix up class 6a arg 6 -> 4, class 7b arg 7 -> 6",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:tracking/ru-verb/conj-%s" % vclass for vclass in ["6a", "7b"]])
