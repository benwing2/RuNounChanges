#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn in ["hi-noun form", "hi-verb form", "hi-adj form"]:
      g = getparam(t, "g")
      newg = None
      if g == "ms":
        newg = "m-s"
      elif g == "fs":
        newg = "f-s"
      elif g == "mp":
        newg = "m-p"
      elif g == "fp":
        newg = "f-p"
      if g != newg:
        t.add("g", newg)
        notes.append("fix gender in {{%s}}" % tn)
      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Fix genders in Hindi noun/verb/adjective forms",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_cats=["Pages with module errors"])
