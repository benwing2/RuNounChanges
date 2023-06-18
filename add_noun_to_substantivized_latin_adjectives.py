#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  def fix_up_section(sectext, indent):
    subsections = re.split("(^%s[^=\n]+=+\n)" % indent, sectext, 0, re.M)
    saw_adecl = False
    for k in range(2, len(subsections), 2):
      parsed = blib.parse_text(subsections[k])
      la_adecl_template = None
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "la-adecl":
          if la_adecl_template:
            pagemsg("WARNING: Saw multiple {{la-adecl}} templates: %s and %s" % (
              la_adecl_template, t))
          else:
            la_adecl_template = t
            saw_adecl = True
      if not la_adecl_template:
        continue
      split_subsec = re.split("(^# .*substantive.*\n)", subsections[k], 0, re.M)
      remaining_parts = []
      defn_parts = []
      if len(split_subsec) == 1:
        pagemsg("WARNING: Didn't see substantive defn, skipping")
        continue
      for i in range(len(split_subsec)):
        if i % 2 == 0:
          remaining_parts.append(split_subsec[i])
        else:
          defn_parts.append(split_subsec[i])
      param1 = getparam(la_adecl_template, "1")
      if param1.endswith("us"):
        param1 += "<2>"
        gspec = ""
      elif param1.endswith("is"):
        param1 += "<3>"
        gspec = "|g=m"
      else:
        pagemsg("WARNING: Unrecognized ending on param1: %s" % param1)
        gspec = ""
      subsections[k] = ("".join(remaining_parts).rstrip('\n') +
        "\n\n%sNoun%s\n{{la-noun|%s%s}}\n\n%s\n%s=Declension=%s\n{{la-ndecl|%s}}\n\n" % (
          indent, indent, param1, gspec, "".join(defn_parts), indent, indent,
          param1))
      notes.append("add noun section with {{la-noun|%s|%s}} to substantivized Latin adjective" %
          (param1, gspec))
    if not saw_adecl:
      pagemsg("WARNING: Saw no {{la-adecl}} in section")
    return "".join(subsections)

  # If there are multiple Etymology sections, split on them, otherwise do
  # whole section.
  has_etym_1 = "==Etymology 1==" in text
  if not has_etym_1:
    text = fix_up_section(text, "===")
  else:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", text, 0, re.M)
    for k in range(2, len(etym_sections), 2):
      etym_sections[k] = fix_up_section(etym_sections[k], "====")
    text = "".join(etym_sections)

  return text, notes

parser = blib.create_argparser("Add noun to substantivized Latin adjectives",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
