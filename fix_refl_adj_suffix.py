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

  pagemsg("Processing")

  if not pagetitle.endswith(u"ся"):
    return

  text = str(page.text)
  notes = []

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    origt = str(t)
    if str(t.name) in ["ru-decl-adj", "ru-adj-old"] and getparam(t, "suffix") == u"ся":
      lemma = getparam(t, "1")
      lemma = re.sub(",", u"ся,", lemma)
      lemma = re.sub("$", u"ся", lemma)
      t.add("1", lemma)
      rmparam(t, "suffix")
      notes.append(u"move suffix=ся to lemma")
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser(u"Rewrite reflexive adjectival participle declensions involving suffix=ся to put suffix in the lemma",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:ru-decl-adj", "Template:ru-adj-old"])
