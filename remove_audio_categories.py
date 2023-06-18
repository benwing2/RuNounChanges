#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  parsed = blib.parse(page)

  found_audio = False
  for t in parsed.filter_templates():
    if str(t.name) == "audio" and getparam(t, "lang") == "ru":
      found_audio = True
      break
  if found_audio:
    new_text = re.sub(r"\n*\[\[Category:Russian terms with audio links]]\n*", "\n\n", text)
    if new_text != text:
      return new_text, "Remove redundant [[:Category:Russian terms with audio links]]"

parser = blib.create_argparser("Remove redundant audio-link categories",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian terms with audio links"])
