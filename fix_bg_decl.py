#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def do_process_text_on_page(index, pagename, text, adj):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  if "==Etymology 1==" in text or "==Pronunciation 1==" in text:
    pagemsg("WARNING: Saw Etymology/Pronunciation 1, can't handle yet")
    return

  parsed = blib.parse_text(text)
  headword = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in (adj and ["bg-adj"] or ["bg-noun", "bg-proper noun"]):
      headword = getparam(t, "1")
    if (tn == "bg-decl-adj" if adj else tn.startswith("bg-noun-")):
      origt = str(t)
      if not headword:
        pagemsg("WARNING: Saw %s without {{%s}} headword" % (origt, "bg-adj" if adj else "bg-noun"))
        continue
      del t.params[:]
      t.add("1", "%s<>" % headword)
      blib.set_template_name(t, "bg-adecl" if adj else "bg-ndecl")
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("convert {{%s}} to {{%s}}" % (tn, tname(t)))

  return text, notes

parser = blib.create_argparser("Use {{bg-ndecl}}/{{bg-adecl}} for Bulgarian declensions",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--adj", help="Do adjectives instead of nouns", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def process_text_on_page(index, pagetitle, text):
  return do_process_text_on_page(index, pagetitle, text, args.adj)
blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
