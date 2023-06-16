#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "docparam":
      para1 = getparam(t, "1") or "1"
      para2 = getparam(t, "2")
      req = False
      opt = False
      if re.search(r"^'*required'*$", para2):
        req = True
        para2 = None
      elif re.search(r"^'*optional'*$", para2):
        opt = True
        para2 = None
      origt = str(t)
      t.add("1", para1)
      if para2:
        t.add("2", "")
        t.add("3", para2)
      else:
        rmparam(t, "2")
      if req:
        t.add("req", "1")
      if opt:
        t.add("opt", "1")
      blib.set_template_name(t, "para")
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      if para2:
        pagemsg("Set additional info param 3=%s in %s" % (para2, str(t)))
      notes.append(u"convert {{docparam}} to {{para}}")

  return str(parsed), notes

parser = blib.create_argparser("Deprecate {{docparam}} in favor of {{para}}",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
