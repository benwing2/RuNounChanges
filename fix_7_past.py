#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("WARNING: Script no longer applies and would need fixing up")
  return

  pagemsg("Processing")

  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    if str(t.name) in ["ru-conj-7a", "ru-conj-7b"]:
      past_stem = getparam(t, "4")
      vowel_end = re.search("[аэыоуяеиёю́]$", past_stem)
      past_m = getparam(t, "past_m")
      past_f = getparam(t, "past_f")
      past_n = getparam(t, "past_n")
      past_pl = getparam(t, "past_pl")
      if past_m or past_f or past_n or past_pl:
        upast_stem = rulib.make_unstressed_ru(past_stem)
        expected_past_m = past_stem + ("л" if vowel_end else "")
        expected_past_f = upast_stem + "ла́"
        expected_past_n = upast_stem + "ло́"
        expected_past_pl = upast_stem + "ли́"
        if ((not past_m or expected_past_m == past_m) and
            expected_past_f == past_f and
            expected_past_n == past_n and
            expected_past_pl == past_pl):
          msg("Would remove past overrides and add arg5=b")
        else:
          msg("WARNING: Remaining past overrides: past_m=%s, past_f=%s, past_n=%s, past_pl=%s, expected_past_m=%s, expected_past_f=%s, expected_past_n=%s, expected_past_pl=%s" %
              (past_m, past_f, past_n, past_pl, expected_past_m, expected_past_f, expected_past_n, expected_past_pl))
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser("Convert class-7 past overrides to past stress pattern",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian class 7 verbs"])
