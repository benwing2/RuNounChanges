#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

headers_to_swap = [
  "Further reading",
  "See also",
  "Statistics",
  "References",
  "Anagrams",
]

headers_to_swap_regex = "(%s)" % "|".join(headers_to_swap)

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "English", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in range(1, len(subsections) - 2, 2):
    if (re.search(r"==%s==" % headers_to_swap_regex, subsections[k])
        and re.search("==Translations==", subsections[k + 2])):
      notes.append("swap %s and %s sections" % (subsections[k].strip(), subsections[k + 2].strip()))
      temp = subsections[k]
      subsections[k] = subsections[k + 2]
      subsections[k + 2] = temp
      temp = subsections[k + 1]
      subsections[k + 1] = subsections[k + 3]
      subsections[k + 3] = temp

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)
  return text, notes

parser = blib.create_argparser("Swap misordered Translations sections",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
