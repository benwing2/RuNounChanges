#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, warn_on_no_change=False):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  origtext = text
  notes = []

  def fix_indent(text, header, lto):
    lto_text = "=" * lto
    newtext = re.sub("^===+%s===+$" % header,
        "%s%s%s" % (lto_text, header, lto_text), text, 0, re.M)
    if newtext != text:
      notes.append("fix %s indentation" % header)
    return newtext

  foundrussian = False
  sections = re.split("(^==[^=\n]*==\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

    if "===Etymology 1===" in sections[j]:
      pagemsg("WARNING: Skipping page because ===Etymology 1===")
      return

    sections[j] = fix_indent(sections[j], "Pronunciation", 3)
    sections[j] = fix_indent(sections[j], "Alternative forms", 3)
    sections[j] = fix_indent(sections[j], "Declension", 4)
    sections[j] = fix_indent(sections[j], "Conjugation", 4)

  text = "".join(sections)

  if origtext != text:
    return text, notes
  elif warn_on_no_change:
    pagemsg("WARNING: No changes")

parser = blib.create_argparser(u"Fix indentation of Pronunciation, Declension, Conjugation, Alternative forms sections",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def do_process_page(page, index, parsed):
  if args.pagefile:
    return process_page(page, index, warn_on_no_change=True)
  else:
    return process_page(page, index, warn_on_no_change=False)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_cats=["Russian lemmas", "Russian non-lemma forms"])
