#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

def process_text_on_page(index, pagename, text):
  pagename = pagename[0].lower() + pagename[1:]
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  if "==Etymology 1==" in text:
    pagemsg("WARNING: Saw Etymology 1, can't handle yet")
    return

  parsed = blib.parse_text(text)
  orig_headword = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["la-IPA", "la-adj", "la-adecl"]:
      param1 = getparam(t, "1")
      if param1:
        if tn == "la-adj":
          orig_headword = param1
        param1 = param1[0].lower() + param1[1:]
        origt = str(t)
        t.add("1", param1)
        pagemsg("Replaced %s with %s" % (origt, str(t)))
  text = str(parsed)

  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
  if len(subsections) < 3:
    pagemsg("Something wrong, only one subsection")
    return
  notes.append("lowercase Latin adjective")
  if orig_headword:
    alter_line = "* {{alter|la|%s||alternative case form}}" % orig_headword
    if "==Alternative forms==" in subsections[1]:
      subsections[2] = subsections[2].rstrip('\n') + "\n%s\n\n" % alter_line
    else:
      subsections[1:1] = [
        "===Alternative forms===\n",
        alter_line + "\n\n"
      ]
    notes.append("add uppercase equivalent as alternative case form")

  return text, notes

parser = blib.create_argparser("Lowercase Latin adjectives; use with find_regex.py")
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
