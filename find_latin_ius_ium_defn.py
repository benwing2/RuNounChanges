#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Latin", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in range(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      origt = str(t)
      tn = tname(t)
      if tn in ["la-noun", "la-proper noun"]:
        param1 = getparam(t, "1")
        has_no_short_gen = re.search(r"(\b|\.)-iu[sm]\b", param1)
        defns = blib.find_defns(subsections[k], "la")
        msg("|-")
        msg("| %s || %s || %s ||  ?  || %s" % (pagetitle, param1, "yes" if has_no_short_gen else "no", ";".join(defns)))

parser = blib.create_argparser("Find -ius/-ium nouns with/without short genitive, with corresponding defns",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

msg('{|class="wikitable"')
msg("! Lemma !! Declension !! Has Short Gen !! Wrong? !! Defn")
blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, stdin=True,
    default_cats=["Latin nouns"], filter_pages=lambda pagetitle: re.search("iu[sm]$", pagetitle))
msg("|}")
