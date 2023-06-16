#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Czech", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  genders = None
  defns = None
  headt = None
  for k in range(2, len(subsections), 2):
    if re.search("==(Noun|Proper noun)==", subsections[k - 1]):
      parsed = blib.parse_text(subsections[k])
      for t in parsed.filter_templates():
        origt = str(t)
        tn = tname(t)
        if tn in ["cs-noun", "cs-proper noun"]:
          if headt is not None:
            pagemsg("WARNING: Saw two headwords %s and %s" % (str(headt), str(t)))
          headt = t
          genders = blib.fetch_param_chain(t, "1", "g")
          defns = blib.find_defns(subsections[k], "la")
    elif "==Declension==" in subsections[k - 1] and "{{rfinfl|cs|" in subsections[k]:
      if genders is None or defns is None:
        pagemsg("WARNING: Saw ==Declension== section without preceding headword")
        continue
      m = re.search(r"\{\{rfinfl\|cs\|[^{}]*\}\}", subsections[k])
      assert m
      rfinfl = m.group(0)
      pagemsg("<from> %s <to> %s <end> <from> %s <to> %s <end> gender: %s; defn: %s" % (rfinfl, rfinfl, str(headt),
        str(headt), ",".join(genders), ";".join(defns)))

parser = blib.create_argparser("Find Czech nouns needing declension and output corresponding gender and definition",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)
blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, stdin=True,
  default_cats=["Requests for inflections in Czech noun entries"])
