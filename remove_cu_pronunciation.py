#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_text_on_page(index, pagetitle, pagetext):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  notes = []

  retval = blib.find_modifiable_lang_section(pagetext, None if args.partial_page else "Old Church Slavonic", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  for k in range(2, len(subsections), 2):
    if "==Pronunciation==" in subsections[k - 1]:
      parsed = blib.parse_text(subsections[k])
      for t in parsed.filter_templates():
        def getp(param):
          return getparam(t, param)
        origt = str(t)
        tn = tname(t)
        if tn != "cu-IPA":
          pagemsg("WARNING: Saw non-{{cu-IPA}} template in Old Church Slavonic pronunciation section: %s" % str(t))
          break
      else: # no break
        subsections[k - 1] = ""
        subsections[k] = ""
        notes.append("remove Pronunciation section with bad {{cu-IPA}} from Old Church Slavonic term")

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes
  
parser = blib.create_argparser("Remove Pronunciation sections with {{cu-IPA}} from Old Church Slavonic terms",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:cu-IPA"], skip_ignorable_pages=True)
