#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "head" and getparam(t, "1") == "bnt-pro" and getparam(t, "2") == "verb":
      rmparam(t, "1")
      rmparam(t, "2")
      # Check for unrecognized params.
      params = []
      unrecognized = False
      for param in t.params:
        pagemsg("Saw unrecognized param %s=%s in %s" % (str(param.name), str(param.value), origt))
        unrecognized = True
      if unrecognized:
        continue
      blib.set_template_name(t, "bnt-verb")
      notes.append("convert {{head|bnt-pro|verb}} to {{bnt-verb}}")
    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Templatize {{head|bnt-pro|verb}} to {{bnt-verb}}", include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_cats=["Proto-Bantu verbs"],
)
