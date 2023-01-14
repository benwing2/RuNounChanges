#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "demonym-noun" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  if " " in pagetitle:
    pagemsg("WARNING: Can't handle space in pagetitle currently")
    return

  if pagetitle.endswith("o"):
    expected_gender = "m"
  elif pagetitle.endswith("a"):
    expected_gender = "f"
  elif pagetitle.endswith("e"):
    expected_gender = "mfbysense"
  else:
    pagemsg("WARNING: Not sure of expected gender, skipping")
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn == "it-noun" and getp("2") != "-": # Skip singular-only nouns, which may be languages or dialects
      g = getp("1")
      if g != expected_gender:
        pagemsg("WARNING: Actual gender %s not same as expected gender %s: %s" % (g, expected_gender, unicode(t)))
        return
    if tn == "demonym-noun":
      origt = unicode(t)
      demonym_g = getp("g")
      if expected_gender == "mfbysense":
        if demonym_g:
          pagemsg("WARNING: Saw gender %s for expected mfbysense term in {{demonym-noun}}: %s" %
            (demonym_g, unicode(t)))
          return
      if demonym_g and demonym_g != expected_gender:
        pagemsg("WARNING: Saw gender %s in {{demonym-noun}} but expected %s: %s" %
          (demonym_g, expected_gender, unicode(t)))
        return
      if not demonym_g and expected_gender != "mfbysense":
        t.add("g", expected_gender)
        notes.append("add g=%s in {{demonym-noun|it}}" % expected_gender)
      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Add missing gender to {{demonym-noun|it}} as needed and check for misspecified genders",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:demonym-noun"])
