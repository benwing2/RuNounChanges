#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if ":" in pagetitle and not re.search("^(Appendix|Reconstruction|Citations):", pagetitle):
    return

  origtext = text
  pagemsg("Processing")
  notes = []

  # Split into sections
  splitsections = re.split(r"(^[ \t]*==[ \t]*[^=\n]+?[ \t]*==[ \t]*?\n)", text, 0, re.M)
  pagehead = splitsections[0]

  # Convert to a list of three items: language name, section header, section text minus separator.
  keyed_sections = []
  for i in range(1, len(splitsections), 2):
    m = re.search(r"=\s*([^=\n]+?)\s*=", splitsections[i])
    assert m
    langname = m.group(1)
    secheader = splitsections[i]
    sectext = splitsections[i + 1]
    m = re.search(r"^(.*?\n)(\n*--+\n*)$", sectext, re.S)
    if m:
      sectext = m.group(1)
    keyed_sections.append([langname, secheader, sectext])

  # Make sure new language section not already present.
  for i in range(len(keyed_sections)):
    if keyed_sections[i][0] == args.tolang:
      pagemsg("WARNING: Already saw %s section, skipping" % args.tolang)
      return

  # Change language name.
  for i in range(len(keyed_sections)):
    if keyed_sections[i][0] == args.fromlang:
      keyed_sections[i][0] = args.tolang
      keyed_sections[i][1] = re.sub("=[ \t]*%s[ \t]*=" % re.escape(args.fromlang), "=%s=" % args.tolang, keyed_sections[i][1])

  # Re-sort add combine with separators.
  def lang_sort_key(langname):
    if langname == "Translingual":
      return (0, langname)
    elif langname == "English":
      return (1, langname)
    else:
      return (2, langname)

  separator = "\n----\n\n"
  text = pagehead + separator.join(
    secheader + sectext for langname, secheader, sectext in sorted(keyed_sections, key=lambda sec: lang_sort_key(sec[0]))
  )

  if text != origtext:
    notes.append("move %s section to %s" % (args.fromlang, args.tolang))
  return text, notes

parser = blib.create_argparser("Move entries from one language to another", include_pagefile=True, include_stdin=True)
parser.add_argument("--fromlang", required=True, help="Existing language to rename.")
parser.add_argument("--tolang", required=True, help="New name of language.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
