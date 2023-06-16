#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "en-noun" not in text:
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn == "en-noun":
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn != "1":
          pagemsg("Template has %s=, not touching: %s" % (pn, origt))
          must_continue = True
          break
      if must_continue:
        continue
      par1 = getparam(t, "1")
      if par1 == pagetitle + "s" or par1 == "s":
        rmparam(t, "1")
        notes.append("remove redundant 1=%s from {{%s}}" % (par1, tn))
      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Remove redundant plural from *-noun for certain languages",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:en-noun"])
