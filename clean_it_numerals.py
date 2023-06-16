#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  text = str(page.text)

  if len(re.findall("^#", text, re.M)) >= 3:
    pagemsg("WARNING: Page has 3 or more definition lines, skipping")
    return
  if "===Adjective===" in text and "===Etymology===" not in text:
    cento_split = re.split("(cento)", pagetitle)
    if len(cento_split) != 3:
      pagemsg("WARNING: Can't split %s on -cento-" % pagetitle)
      return
    text = text.replace("===Adjective===", "===Etymology===\n{{affix|it|%s%s|%s}}\n\n===Adjective===" % tuple(cento_split))
  text = re.sub(r"(\[\[[a-z -]*hundred)\|.*?\]\]", r"\1]]", text)
  text = re.sub(r"^(#.*)\.$", r"\1", text, 0, re.M)
  text = re.sub(r"===Noun===\n\{\{it-noun\|m\|-\}\}", "===Numeral===\n{{head|it|numeral}}", text)
  notes.append("clean up Italian numerals")
  return text, notes

parser = blib.create_argparser("Clean up Italian numerals to use {{head|it|numeral}}", include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
