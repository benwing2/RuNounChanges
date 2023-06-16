#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site, tname

book_map = {
  "Gen": "Jenesis",
  "Exod": "Kisim Bek",
  "Lev": "Wok Pris",
  "Num": "Namba",
  "Deut": "Lo",
}

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn == "RQ:Buk Baibel":
      param1 = getparam(t, "1")
      if param1 in book_map:
        t.add("1", book_map[param1])
        notes.append("convert '%s' to '%s' in 1= in {{%s}}" % (param1, book_map[param1], tn))
      param4 = getparam(t, "4")
      if param4:
        t.add("passage", param4, before="4")
        rmparam(t, "4")
        notes.append("4= -> passage= in {{%s}}" % tn)

    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Reformat {{RQ:Buk Baibel}}", include_pagefile=True,
    include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:RQ:Buk Baibel"], edit=True, stdin=True)
