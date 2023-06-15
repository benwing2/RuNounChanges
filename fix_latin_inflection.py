#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  subsections = re.split("(^==.*==\n)", secbody, 0, re.M)

  notes = []

  for k in range(2, len(subsections), 2):
    if "==Inflection==" in subsections[k - 1]:
      parsed = blib.parse_text(subsections[k])
      poses = set()
      for t in parsed.filter_templates():
        pos = lalib.la_infl_template_pos(t)
        if pos:
          poses.add(pos)
      poses = sorted(list(poses))
      if len(poses) > 1:
        pagemsg("WARNING: Saw inflection templates for multiple parts of speech: %s" % ",".join(poses))
      elif len(poses) == 0:
        pagemsg("WARNING: Saw no inflection templates in ==Inflection== section")
      else:
        if poses[0] == "verb":
          subsections[k - 1] = subsections[k - 1].replace("Inflection", "Conjugation")
          notes.append("convert Latin ==Inflection== header to ==Conjugation==")
        else:
          subsections[k - 1] = subsections[k - 1].replace("Inflection", "Declension")
          notes.append("convert Latin ==Inflection== header to ==Declension==")

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert Latin ==Inflection== headers to ==Conjugation== or ==Declension==",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
