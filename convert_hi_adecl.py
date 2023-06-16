#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

AA = u"\u093e"
M = u"\u0901"
IND_AA = u"आ"

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace page")
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["hi-adj-1"]:
      rmparam(t, "1")
      rmparam(t, "2")
      blib.set_template_name(t, "hi-adecl")
      notes.append("convert {{%s}} to {{hi-ndecl}}" % tn)
    if tn in ["hi-adj-auto"]:
      if " " not in pagetitle and "-" not in pagetitle and (
        pagetitle.endswith(AA) or pagetitle.endswith(IND_AA)
      ):
        blib.set_template_name(t, "hi-adecl")
        notes.append("convert {{%s}} to {{hi-ndecl}}" % tn)
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser(u"Convert old Hindi adjective declension templates to new ones",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:hi-adj-1", "Template:hi-adj-auto"], edit=True, stdin=True)
