#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

blib.getData()

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  def do_templatize(subsectext, langname, subsectitle):
    if not subsectitle.startswith("Etymology"):
      return subsectext
    if langname not in blib.languages_byCanonicalName:
      pagemsg("WARNING: Unknown language %s" % langname)
      return subsectext
    else:
      langcode = blib.languages_byCanonicalName[langname]["code"]

    def replace_unknown_uncertain(m, template):
      newtemp = "{{%s|%s}}" % (template, langcode)
      notes.append("replace '%s' with %s" % (m.group(2), newtemp))
      return m.group(1) + newtemp

    def generate_regex_template(cap, lc):
      return (r"((?:\{\{.*\}\}\n)*)(%s +(etymology|origin)|%s|(Etymology|Origin) +%s|Of +%s +(etymology|origin))"
        % (cap, cap, lc, lc))
      
    subsectext = re.sub(generate_regex_template("Unknown", "unknown"),
        lambda m: replace_unknown_uncertain(m, "unk"), subsectext)
    subsectext = re.sub(generate_regex_template("Uncertain", "uncertain"),
        lambda m: replace_unknown_uncertain(m, "unc"), subsectext)
    return subsectext

  pagemsg("Processing")

  sections = re.split("(^\s*==[^=]*==\s*\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    m = re.search(r"^\s*==\s*(.*?)\s*==\s*\n$", sections[j - 1])
    assert m
    langname = m.group(1)
    subsections = re.split("(^\s*==.*==\s*\n)", sections[j], 0, re.M)
    for k in range(2, len(subsections), 2):
      m = re.search("^\s*===*\s*(.*?)\s*=*==\s*\n$", subsections[k - 1])
      assert m
      subsectitle = m.group(1)
      subsections[k] = do_templatize(subsections[k], langname, subsectitle)
    sections[j] = "".join(subsections)

  newtext = "".join(sections)
  return newtext, notes

parser = blib.create_argparser("Templatize 'unknown'/'uncertain' in Etymology sections, based on the section it's within",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
