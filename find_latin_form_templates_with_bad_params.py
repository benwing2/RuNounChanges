#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  # Greatly speed things up when --stdin by ignoring non-Latin pages
  if "==Latin==" not in text:
    return

  if not re.search("la-(noun|proper noun|pronoun|verb|adj|num|suffix)-form", text):
    return

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return
  
  sections, j, secbody, sectail, has_non_latin = retval

  parsed = blib.parse_text(secbody)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["la-noun-form", "la-proper noun-form", "la-pronoun-form", "la-verb-form",
        "la-adj-form", "la-num-form", "la-suffix-form"]:
      if not getparam(t, "1"):
        pagemsg("WARNING: Missing 1=: %s" % str(t))
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "g", "g2", "g3", "g4"]:
          pagemsg("WARNING: Extraneous param %s=: %s" % (pn, str(t)))

parser = blib.create_argparser("Check for Latin non-lemma forms with bad params",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Latin non-lemma forms"])
