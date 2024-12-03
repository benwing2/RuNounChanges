#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Icelandic", pagemsg,
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
        if tn in ["is-noun/old", "is-proper noun/old"]:
          if headt is not None:
            pagemsg("WARNING: Saw two headwords %s and %s" % (str(headt), str(t)))
          headt = t
          headt_genders = ",".join(blib.fetch_param_chain(headt, ["1", "g", "gen"], "g")) or "?"
          headt_gens = blib.fetch_param_chain(headt, "2", "gen")
          headt_pls = blib.fetch_param_chain(headt, ["3", "pl"], "pl")
          defns = blib.find_defns(subsections[k], "is")
          if tn == "is-proper noun/old":
            new_decl = "{{is-ndecl|%s}}" % headt_genders
          elif pagetitle[0].isupper():
            new_decl = "{{is-ndecl|%s.dem}}" % headt_genders
          elif headt_pls == ["-"]:
            new_decl = "{{is-ndecl|%s.sg}}" % headt_genders
          else:
            new_decl = "{{is-ndecl|%s}}" % headt_genders
          pagemsg("<begin> %s <end> <begin> %s <end> defn: %s" % (new_decl, origt, ";".join(defns)))

parser = blib.create_argparser("Find Icelandic nouns needing declension and output headword, suggested declension and definition",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)
blib.do_pagefile_cats_refs(
    args, start, end, process_text_on_page, stdin=True,
    default_refs=["Template:is-noun/old", "Template:is-proper noun/old"])
