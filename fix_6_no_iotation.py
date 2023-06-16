#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("WARNING: Script no longer applies and would need fixing up")
  return

  pagemsg("Processing")

  text = str(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    param1 = getparam(t, "1")
    if str(t.name) in ["ru-conj"]:
      if re.search(r"^6[ac]", param1):
        if getparam(t, "no_iotation"):
          rmparam(t, "no_iotation")
          if param1.startswith("6a"):
            notes.append(u"6a + no_iotation -> 6°a")
          else:
            notes.append(u"6c + no_iotation -> 6°c")
          t.add("1", re.sub("^6", u"6°", param1))
      elif re.search(r"^6b", param1):
        notes.append(u"6b -> 6°b")
        t.add("1", re.sub("^6", u"6°", param1))
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser("Fix up class-6 no-iotation verbs",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian class 6 verbs"])
