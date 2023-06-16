#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Rearrange {{was wotd}} to go after ==English==.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  origtext = str(page.text)
  text = origtext
  text = re.sub(r"(\{\{was wotd\|.*?\}\}\n)(==English==\n)", r"\2\1", text)
  notes = ["put {{was wotd}} after ==English== per [[User:Smuconlaw]]"]

  return text, notes

parser = blib.create_argparser("Rearrange {{was wotd}} to go after ==English==",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:was wotd"])
