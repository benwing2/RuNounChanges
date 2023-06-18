#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

tempname_to_header = {
  "la-noun-form": "Noun",
  "la-verb-form": "Verb",
  "la-adj-form": "Adjective",
  "la-proper noun-form": "Proper noun",
  "la-proper-noun-form": "Proper noun",
  "la-part-form": "Participle",
  "la-pronoun-form": "Pronoun",
}

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  notes = []
  for k in range(2, len(subsections), 2):
    newtext = re.sub(r"^\n*(\{\{la-.*?-form)", r"\1", subsections[k])
    if newtext != subsections[k]:
      notes.append("remove extraneous newlines before Latin non-lemma headword")
    indent = len(re.sub("^(=+).*\n", r"\1", subsections[k - 1]))
    def add_header(m):
      lastchar, tempname = m.groups()
      if tempname in tempname_to_header:
        header_pos = tempname_to_header[tempname]
      else:
        pagemsg("WARNING: Unrecognized template name: %s" % tempname)
        return m.group(0)
      header = "=" * indent + header_pos + "=" * indent
      preceding_newline = "\n" if lastchar != "\n" else ""
      return lastchar + "\n" + preceding_newline + header + "\n{{" + tempname
     
    newnewtext = re.sub(r"([^=])\n\{\{(la-[a-z -]*?-form)", add_header, newtext)
    if newnewtext != newtext:
      notes.append("add missing header before Latin non-lemma form")
    subsections[k] = newnewtext
  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Add missing header to Latin non-lemma terms",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
