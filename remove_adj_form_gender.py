#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Remove gender from Russian adjective forms.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = str(page.text)
  notes = []

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      # Remove gender from adjective forms
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if str(t.name) == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "adjective form":
          origt = str(t)
          rmparam(t, "g")
          rmparam(t, "g2")
          rmparam(t, "g3")
          rmparam(t, "g4")
          newt = str(t)
          if origt != newt:
            pagemsg("Replaced %s with %s" % (origt, newt))
            notes.append("remove gender from adjective forms")
      sections[j] = str(parsed)
  new_text = "".join(sections)

  return new_text, notes

parser = blib.create_argparser("Remove gender from Russian adjective forms",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian adjective forms"])
