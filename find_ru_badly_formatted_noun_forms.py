#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  found_inflection_of = False
  for t in parsed.filter_templates():
    if tname(t) in ["inflection of"]:
      found_inflection_of = True
  if not found_inflection_of:
    pagemsg("WARNING: No 'inflection of'")

parser = blib.create_argparser("Find badly formatted Russian noun forms",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian noun forms"])
