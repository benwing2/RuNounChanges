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

  headword_template = None
  see_template = None
  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-noun+", "ru-proper noun+"]:
      if headword_template:
        pagemsg("WARNING: Multiple headword templates, skipping")
        return
      headword_template = t
    if unicode(t.name) in ["ru-decl-noun-see"]:
      if see_template:
        pagemsg("WARNING: Multiple ru-decl-noun-see templates, skipping")
        return
      see_template = t
  if not headword_template:
    pagemsg("WARNING: No ru-noun+ or ru-proper noun+ templates, skipping")
    return
  if not see_template:
    pagemsg("WARNING: No ru-decl-noun-see templates, skipping")
    return

  FIXME

parser = argparse.ArgumentParser(description="Convert ru-decl-noun-see into ru-noun-table decl template")
parser.add_argument('start', help="Starting page index", nargs="?")
parser.add_argument('end', help="Ending page index", nargs="?")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for index, page in blib.references("Template:ru-decl-noun-see", start, end):
  process_page(index, page)
