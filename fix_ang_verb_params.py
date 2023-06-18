#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  text = str(page.text)
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn == "head" and getparam(t, "1") == "ang" and getparam(t, "2") in ["verb", "verbs"]:
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "head"]:
          pagemsg("WARNING: head|ang|verb with extra params: %s" % str(t))
          break
      else:
        # no break
        blib.set_template_name(t, "ang-verb")
        rmparam(t, "1")
        rmparam(t, "2")
        notes.append("convert {{head|ang|verb}} into {{ang-verb}}")
        head = getparam(t, "head")
        if head:
          t.add("1", head)
        rmparam(t, "head")
    elif tn == "ang-verb":
      head = getparam(t, "head")
      head2 = getparam(t, "head2")
      head3 = getparam(t, "head3")
      rmparam(t, "head")
      rmparam(t, "head2")
      rmparam(t, "head3")
      if head:
        t.add("1", head)
      if head2:
        t.add("head2", head2)
      if head3:
        t.add("head3", head3)
      notes.append("move head= to 1= in {{ang-verb}}")
    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))
  return parsed, notes

parser = blib.create_argparser("Fix Old English verb headwords to new format",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Old English verbs"], edit=1)
