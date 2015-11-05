#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

import rulib as ru

site = pywikibot.Site()

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

def process_page(index, page):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  parsed = blib.parse(page)

  found_headword_template = False
  found_decl_template = False
  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-noun", "ru-proper noun"]:
      found_headword_template = True
    if unicode(t.name) in ["ru-noun-table", "ru-decl-noun-see"]:
      found_decl_template = True
  if found_headword_template and not found_decl_template:
    pagemsg("Found headword template without decl")

parser = argparse.ArgumentParser(description="Find nouns without declension")
parser.add_argument('start', help="Starting page index", nargs="?")
parser.add_argument('end', help="Ending page index", nargs="?")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for pos in ["nouns", "proper nouns"]:
  tracking_page = "Template:tracking/ru-headword/space-in-headword/" + pos
  msg("Processing references to %s" % tracking_page)
  for index, page in blib.references(tracking_page, start, end):
    process_page(index, page)
