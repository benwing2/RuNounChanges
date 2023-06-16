#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

non_adjectival_names = [
  u"Дарвин"
]

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if pagetitle in non_adjectival_names:
    pagemsg("Skipping explicitly-specified non-adjectival name")
    return

  text = str(page.text)
  parsed = blib.parse(page)
  notes = []

  proper_noun_headword = None
  surname_template = None
  ru_adj11_template = None

  for t in parsed.filter_templates():
    tname = str(t.name)
    if tname == "ru-proper noun":
      pagemsg("WARNING: Found old ru-proper noun: %s" % str(t))
    elif tname == "ru-proper noun+":
      name = getparam(t, "1")
      if not (not getparam(t, 2) or getparam(t, "2") == "+" and not getparam(t, "3")):
        pagemsg("WARNING: Complex proper noun header, not sure how to handle: %s" % str(t))
      else:
        if re.search(u"([оеё]́?в|и́?н)$", name):
          new_fem = name + u"а"
        elif re.search(u"ый$", name):
          new_fem = re.sub(u"ый$", u"ая", name)
        elif re.search(u"о́й$", name):
          new_fem = re.sub(u"о́й$", u"а́я", name)
        elif re.search(u"[кгхчшжщ]ий$", name):
          new_fem = re.sub(u"ий$", u"ая", name)
        else:
          new_fem = None
          if re.search(u"ий$", name):
            pagemsg(u"WARNING: Name ending in non-velar/hushing consonant + -ий: %s" % str(t))
        if new_fem:
          if getparam(t, "2") != "+":
            pagemsg("WARNING: Adjectival name not correctly conjugated in headword, fixing: %s" % str(t))
            origt = str(t)
            t.add("2", "+", before="a")
            notes.append("add adjectival + to %s" % name)
            pagemsg("Replacing %s with %s" % (origt, str(t)))
          existing_fem = getparam(t, "f")
          if existing_fem:
            if new_fem != existing_fem:
              pagemsg("WARNING: New feminine %s different from existing feminine %s, not changing: %s" %
                  (new_fem, existing_fem, str(t)))
          else:
            origt = str(t)
            t.add("f", new_fem)
            notes.append("add feminine %s to %s" % (new_fem, name))
            pagemsg("Replacing %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Add feminines to Russian proper names",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian surnames"])
