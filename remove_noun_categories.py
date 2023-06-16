#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, do_noun):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  parsed = blib.parse(page)

  cat = do_noun and "nouns" or "proper nouns"
  new_text = re.sub(r"\n\n\n*\[\[Category:Russian %s]]\n\n\n*" % cat, "\n\n", text)
  new_text = re.sub(r"\[\[Category:Russian %s]]\n" % cat, "", new_text)
  return new_text, "Remove redundant [[:Category:Russian %s]]"

parser = blib.create_argparser("Remove redundant 'Russian nouns' category",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def do_process_page_do_noun_true(page, index, parsed):
  return process_page(page, index, do_noun=True)
def do_process_page_do_noun_false(page, index, parsed):
  return process_page(page, index, do_noun=False)

# FIXME! Won't work properly with --pagefile.
blib.do_pagefile_cats_refs(args, start, end, do_process_page_do_noun_true,
    edit=True, default_refs=["Template:ru-noun", "Template:ru-noun+"])
blib.do_pagefile_cats_refs(args, start, end, do_process_page_do_noun_false,
    edit=True, default_refs=["Template:ru-proper noun", "Template:ru-proper noun+"])
