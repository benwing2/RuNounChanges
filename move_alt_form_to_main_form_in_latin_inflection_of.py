#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

import clean_latin_long_vowels

def process_page(page, index, parsed):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "inflection of":
      lang = getparam(t, "lang")
      if lang:
        term_param = 1
      else:
        lang = getparam(t, "1")
        term_param = 2
      if lang != "la":
        continue
      term = getparam(t, str(term_param))
      alt = getparam(t, str(term_param + 1))
      if alt:
        if lalib.remove_macrons(alt) != lalib.remove_macrons(term):
          pagemsg("WARNING: alt not same as term modulo macrons: %s" %
              str(t))
          continue
        origt = str(t)
        t.add(str(term_param), alt)
        t.add(str(term_param + 1), "")
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("move alt param to term param in Latin {{inflection of}}")

  return str(parsed), notes

parser = blib.create_argparser("Move alt form to main form in Latin {{inflection of}}",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
