#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Fix parameters in {{RQ:Milton Paradise Lost}}.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_text_on_page(index, pagetitle, pagetext):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  parsed = blib.parse_text(pagetext)
  for t in parsed.filter_templates():
    def getp(param, nostrip=False):
      val = getparam(t, param)
      if not nostrip:
        val = val.strip()
      return val
    if tname(t) == "RQ:Milton Paradise Lost":
      origt = str(t)
      rmparam(t, "part")
      if getp("edition") == "2nd":
        continue
      t.add("year", "1873")
      notes.append("add year=1873 to {{RQ:Milton Paradise Lost}}")
      param1 = getp("1")
      if re.search("^[0-9]+$", param1) or re.search("^[MCDIVX]+$", param1.upper()):
        param2 = getparam(t, "2") # no strip
        if param2:
          t.add("passage", param2, before="2")
          rmparam(t, "2")
          notes.append("move 2= to passage= in {{RQ:Milton Paradise Lost}}")
        t.add("book", getparam(t, "1"), before="1") # no strip
        rmparam(t, "1")
        notes.append("move Roman or Arabic numeral in 1= to book= in {{RQ:Milton Paradise Lost}}")
      newt = str(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser("Fix params in {{RQ:Milton Paradise Lost}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True, default_refs=["Template:RQ:Milton Paradise Lost"], ref_namespaces=[0])
