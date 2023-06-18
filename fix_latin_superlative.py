#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  lemma = None
  for t in parsed.filter_templates():
    if tname(t) == "la-adecl":
      if lemma:
        pagemsg("WARNING: Saw more than one declension table, first lemma=%s, second template=%s" % (
          lemma, str(t)))
      lemma = getparam(t, "1")
  if not lemma:
    pagemsg("WARNING: Couldn't find declension template")
    return None, None
  for t in parsed.filter_templates():
    if tname(t) == "head" and getparam(t, "1") == "la" and getparam(t, "2") == "adjective superlative form":
      origt = str(t)
      if getparam(t, "3") == "superlative of":
        base_lemma = getparam(t, "4")
        rmparam(t, "head")
        rmparam(t, "4")
        rmparam(t, "3")
        t.add("1", lemma)
        t.add("2", base_lemma)
        blib.set_template_name(t, "la-adj-sup")
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("Use {{la-adj-sup}} instead of {{head|la|...}}")
      else:
        pagemsg("WARNING: Head template doesn't include base form: %s" % str(t))

  return str(parsed), notes

parser = blib.create_argparser("Fix Latin superlatives formatted using {{head|la|...}}",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Latin adjective superlative forms"], edit=True)
