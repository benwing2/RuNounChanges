#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert ru-adv to ru-compararative for comparatives.

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

  sections = re.split("(^==[^=\n]+==\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      subsections = re.split("(^===.*===\n)", sections[j], 0, re.M)
      for k in range(2, len(subsections), 2):
        parsed = blib.parse_text(subsections[k])
        found_adj_comp = False
        found_adv_comp = False
        for t in parsed.filter_templates():
          tname = str(t.name)
          if tname == "comparative of" and getparam(t, "lang") == "ru":
            if getparam(t, "POS") == "adjective":
              found_adj_comp = True
            elif getparam(t, "POS") == "adverb":
              found_adv_comp = True

        if not found_adj_comp and not found_adv_comp:
          continue

        if found_adj_comp and not found_adv_comp:
          pagemsg("WARNING: Found adjective but not adverb 'comparative of'")
        if found_adv_comp and not found_adj_comp:
          pagemsg("WARNING: Found adverb but not adjective 'comparative of'")

        for t in parsed.filter_templates():
          origt = str(t)
          tname = str(t.name)
          template_fixed = False
          if tname == "ru-adv":
            t.name = "ru-comparative"
            template_fixed = True
          elif tname == "head" and getparam(t, "1") == "ru" and (
              getparam(t, "2") == "adverb comparative form"):
            head = getparam(t, "head")
            rmparam(t, "head")
            rmparam(t, "2")
            rmparam(t, "1")
            t.name = "ru-comparative"
            t.add("1", head)
            template_fixed = True
          if template_fixed:
            if found_adj_comp and not found_adv_comp:
              t.add("noadv", "1")
            if found_adv_comp and not found_adj_comp:
              t.add("noadj", "1")
          newt = str(t)
          if origt != newt:
            pagemsg("Replaced %s with %s" % (origt, newt))
            notes.append("convert headword to ru-comparative")
        subsections[k] = str(parsed)
      sections[j] = "".join(subsections)

  return "".join(sections), notes

parser = blib.create_argparser(u"Convert ru-adv to ru-compararative for comparatives",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian comparative adjectives", "Russian comparative adverbs"])
