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

  retval = blib.find_modifiable_lang_section(pagetext, None if args.partial_page else "Polish", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  for k in range(2, len(subsections), 2):
    if "==References==" in subsections[k - 1]:
      newsubsec = re.sub(r"^:?\*\s*\{\{R:pl:NKJP\}\}\n", "", subsections[k], 0, re.M)
      if newsubsec != subsections[k]:
        notes.append("remove {{R:pl:NKJP}} from Polish References section")
        subsections[k] = newsubsec
        if not subsections[k].strip():
          subsections[k - 1] = ""
          subsections[k] = ""
          notes.append("remove now empty References section from Polish term")

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes
  
parser = blib.create_argparser("Remove {{R:pl:NKJP}} from Polish terms", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_cats=["Polish lemmas"], skip_ignorable_pages=True)
