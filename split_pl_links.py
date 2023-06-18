#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

TEMPSEP = u"\uFFF0"
def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  def split_links(m):
    inside = m.group(1).strip()
    hacked_inside = re.sub(r"\]\] *, *\[\[", "]]%s[[" % TEMPSEP, inside)
    parts = hacked_inside.split(TEMPSEP)
    for i in range(len(parts)):
      mm = re.search("^\[\[([^\[\]]*)\]\]$", parts[i])
      if not mm:
        pagemsg("WARNING: Saw unparsable part %s, not changing: %s" % (parts[i], m.group(0)))
        return m.group(0)
      if TEMPSEP in parts[i]:
        pagemsg("WARNING: Internal error: Saw Unicode FFF0 in part %s, not changing: %s" % parts[i], m.group(0))
        return m.group(0)
      parts[i] = "{{l|pl|%s}}" % mm.group(1)
    notes.append("replace multipart {{l|pl|...}} with separate links")
    return ", ".join(parts)

  text = re.sub(r"\{\{l\|pl\|([^{}]*[\[\]][^{}]*)\}\}", split_links, text)
  return text, notes

parser = blib.create_argparser("Split {{l|pl|...}} links containing multiple entries",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
