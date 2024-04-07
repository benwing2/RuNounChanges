#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(pageindex, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (pageindex, pagetitle, txt))

  notes = []

  subsections, subsections_by_header, subsection_headers, subsection_levels = blib.split_text_into_subsections(
      text, pagemsg)
  if "Antonyms" in subsections_by_header:
    for secno in subsections_by_header["Antonyms"]:
      parsed = blib.parse_text(subsections[secno])
      changed = False
      for t in parsed.filter_templates():
        origt = str(t)
        tn = tname(t)
        if tn == "sense":
          blib.set_template_name(t, "antsense")
          pagemsg("Replaced %s with %s" % (origt, str(t)))
          notes.append("{{sense}} -> {{antsense}} in Antonyms section")
          changed = True
        if tn == "s":
          blib.set_template_name(t, "as")
          pagemsg("Replaced %s with %s" % (origt, str(t)))
          notes.append("{{s}} -> {{as}} in Antonyms section")
          changed = True
      if changed:
        subsections[secno] = str(parsed)
  text = "".join(subsections)
  return text, notes

parser = blib.create_argparser("Convert {{sense}}/{{s}} to {{antsense}}/{{as}} in =Antonyms= sections", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
