#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

all_pronuns = []

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  parsed = blib.parse_text(text)

  pronuns = []
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    if tn == "IPA":
      pronuns.extend(blib.fetch_param_chain(t, "2"))
  if pronuns:
    text = "Page %s %s: %s" % (index, pagetitle, " ".join(pronuns))
    if args.sort_by == "index":
      key = index
    elif args.sort_by == "rtl":
      key = (pagetitle[::-1], index)
    else:
      key = (-len(pagetitle), index)
    all_pronuns.append((key, text))

parser = blib.create_argparser("Find manual pronunciations using {{IPA|LANG}}",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--sort-by", choices=["index", "length", "rtl"], default="index",
  help="How to sort pronunciations; 'index' = by original index (preserve order), 'length' = by word length, 'rtl' = right to left")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, stdin=True)
all_pronuns = sorted(all_pronuns)
for key, text in all_pronuns:
  msg(text)
