#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import belib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  head = None
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "be-decl-noun":
      t.name = "be-decl-noun\n"
      for i in [2, 4, 6, 8, 10, 12]:
        val = getparam(t, str(i)).strip()
        if val:
          t.add(str(i), val + "\n", preserve_spacing=False)
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("format {{be-decl-noun}} using newlines")

  return str(parsed), notes

parser = blib.create_argparser(u"Format be-decl-noun using newlines",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_refs=["Template:be-decl-noun"], edit=True)
