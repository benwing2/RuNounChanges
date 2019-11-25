#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  text = unicode(page.text)
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = unicode(t)
    if tn == "head" and getparam(t, "1") == "ang" and getparam(t, "2") in ["adjective", "adjectives"]:
      pagemsg("WARNING: {{head}} for adjectives, should not occur: %s" % unicode(t))
    elif tn == "ang-adj":
      if getparam(t, "1"):
        pagemsg("WARNING: 1= in ang-adj, should not occur: %s" % unicode(t))
      else:
        head = getparam(t, "head")
        rmparam(t, "head")
        if head:
          t.add("1", head)
        notes.append("move head= to 1= in {{ang-adj}}")
    if unicode(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, unicode(t)))
  return parsed, notes

parser = blib.create_argparser("Fix Old English adjective headwords to new format part 2",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Old English adjectives"], edit=1)
