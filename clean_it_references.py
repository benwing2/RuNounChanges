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

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Italian", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  notes = []

  def process_etym_section(sectext):
    references_sec = None
    further_reading_sec = None
    subsections = re.split("(^==+[^=\n]+==+\n)", sectext, 0, re.M)

    for k in range(2, len(subsections), 2):
      if re.search(r"^===*\s*References\s*===* *\n", subsections[k - 1]):
        if references_sec:
          pagemsg("WARNING: Saw two ===References=== sections in a single etym section")
          return sectext
        references_sec = k
      if re.search(r"^===*\s*Further reading\s*===* *\n", subsections[k - 1]):
        if further_reading_sec:
          pagemsg("WARNING: Saw two ===Further reading=== sections in a single etym section")
          return sectext
        further_reading_sec = k

    if not references_sec:
      return sectext
    lines = subsections[references_sec].split("\n")
    should_be_references = []
    should_be_further_reading = []
    for line in lines:
      if re.search(r"(<references\s*/?\s*>|\{\{reflist)", line):
        should_be_references.append(line)
      elif line:
        should_be_further_reading.append(line)
    if should_be_further_reading:
      if further_reading_sec:
        spl = "s" if len(should_be_further_reading) > 1 else ""
        pagemsg("Moving %s line%s from ===References=== to existing ===Further reading=== section" %
          (len(should_be_further_reading), spl))
        notes.append("move %s line%s from Italian ===References=== to existing ===Further reading=== section" %
          (len(should_be_further_reading), spl))
        subsections[further_reading_sec] = (
          subsections[further_reading_sec].rstrip("\n") + "\n" +
          "\n".join(should_be_further_reading) + "\n\n"
        )
      else:
        spl = "s" if len(should_be_further_reading) > 1 else ""
        pagemsg("Moving %s line%s from ===References=== to new ===Further reading=== section" %
          (len(should_be_further_reading), spl))
        notes.append("move %s line%s from Italian ===References=== to new ===Further reading=== section" %
          (len(should_be_further_reading), spl))
        further_reading_header = subsections[references_sec - 1].replace("References", "Further reading")
        further_reading_text = "\n".join(should_be_further_reading) + "\n\n"
        subsections[references_sec + 1: references_sec + 1] = [further_reading_header, further_reading_text]
    if should_be_references:
      spl = "s" if len(should_be_references) > 1 else ""
      pagemsg("Retaining %s line%s in ===References=== section" % (len(should_be_references), spl))
      notes.append("retain %s line%s in Italian ===References=== section" % (len(should_be_references), spl))
      subsections[references_sec] = "\n".join(should_be_references) + "\n\n"
    else:
      pagemsg("Removing now-blank ===References=== section")
      notes.append("remove now-blank Italian ===References=== section")
      subsections[references_sec - 1] = ""
      subsections[references_sec] = ""
    return "".join(subsections)

  has_etym_1 = "==Etymology 1==" in secbody

  if not has_etym_1:
    secbody = process_etym_section(secbody)
  else:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    if len(etym_sections) < 5:
      pagemsg("WARNING: Something wrong, saw 'Etymology 1' but didn't see two etym sections")
    else:
      for k in range(2, len(etym_sections), 2):
        etym_sections[k] = process_etym_section(etym_sections[k])
        secbody = "".join(etym_sections)

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  return text, notes

parser = blib.create_argparser("Move non-references in Italian ===References=== sections to ===Further reading===",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Italian' and has no ==Italian== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
