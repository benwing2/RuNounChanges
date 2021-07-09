#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not args.partial_page:
    retval = blib.find_modifiable_lang_section(text, args.langname, pagemsg)
    if retval is None:
      return
    sections, j, secbody, sectail, has_non_lang = retval
  else:
    sections = [text]
    j = 0
    secbody, sectail = blib.split_trailing_separator_and_categories(sections[j])

  m = re.search(r"\A(.*?)(\n*)\Z", secbody, re.S)
  secbody, secbody_finalnl = m.groups()
  secbody += "\n\n"

  notes = []

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in xrange(1, len(subsections), 2):
    if re.search("==Anagrams==", subsections[k]):
      if k + 2 < len(subsections):
        subsections = (
          subsections[0:k] + subsections[k + 2:len(subsections)] +
          subsections[k:k + 2]
        )
        notes.append("put Anagrams last in %s section" % args.langname)

  secbody = "".join(subsections)
  sections[j] = secbody.rstrip("\n") + secbody_finalnl + sectail
  return "".join(sections), notes

parser = blib.create_argparser("put Anagrams last", include_pagefile=True, include_stdin=True)
parser.add_argument("--langname", required=True, help="Language name.")
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
