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

  notes = []

  parsed = blib.parse_text(secbody)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "la-decl-3rd-I":
      stem = getparam(t, "1")
      if stem.endswith("polis"):
        blib.set_template_name(t, "la-decl-3rd-polis")
        t.add("1", stem[:-5])
        notes.append("Fix noun in -polis to use {{la-decl-3rd-polis}}")
      else:
        pagemsg("WARNING: Found la-decl-3rd-I without stem in -polis: %s" % unicode(t))
    elif tn == "la-noun":
      blib.set_template_name(t, "la-proper noun")

  secbody = unicode(parsed).replace("==Noun==", "==Proper noun==")

  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Fix Latin declensions of -polis nouns")
parser.add_argument("--pagefile", help="List of pages to process.", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
for i, page in blib.iter_items(pages, start, end):
  blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save,
      verbose=args.verbose, diff=args.diff)
