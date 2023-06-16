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
    tname = str(t.name)
    if tname.startswith("ru-conj-") and tname != "ru-conj-verb-see":
      m = re.search("^ru-conj-(.*)$", tname)
      t.name = "ru-conj"
      conjtype = m.group(1)
      varargno = None
      variant = None
      if conjtype in ["3oa", "4a", "4b", "4c", "6a", "6c", "11a", "16a", "16b", u"irreg-дать", u"irreg-клясть", u"irreg-быть"]:
        varargno = 3
      elif conjtype in ["5a", "5b", "5c", "6b", "9a", "9b", "11b", "14a", "14b", "14c"]:
        varargno = 4
      elif conjtype in ["7b"]:
        varargno = 5
      elif conjtype in ["7a"]:
        varargno = 6
      if varargno:
        variant = getparam(t, str(varargno))
        if re.search("^[abc]", variant):
          variant = "/" + variant
        if getparam(t, str(varargno + 1)) or getparam(t, str(varargno + 2)) or getparam(t, str(varargno + 3)):
          t.add(str(varargno), "")
        else:
          rmparam(t, str(varargno))
        conjtype = conjtype + variant
      notes.append("ru-conj-* -> ru-conj, moving params up by one%s" %
          (variant and " (and move variant spec)" or ""))
      seenval = False
      for i in range(20, 0, -1):
        val = getparam(t, str(i))
        if val:
          seenval = True
        if seenval:
          t.add(str(i + 1), val)
      t.add("1", conjtype)
      blib.sort_params(t)
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser(u"Convert ru-conj-* to ru-conj and move variant",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian verbs"])
