#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  russiansec = blib.find_lang_section(text, "Russian", pagemsg)
  if russiansec is None:
    return

  found_headword_template = False
  parsed = blib.parse_text(russiansec)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "ru-adj" or (tn == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "adjective form"):
      found_headword_template = True
  if not found_headword_template and "===Adjective===" in russiansec:
    pagemsg("WARNING: Missing adj headword template")

parser = blib.create_argparser("Find missing Russian adjective headwords",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian adjectives", "Russian adjective forms", "Russian lemmas",
    "Russian non-lemma forms"])
