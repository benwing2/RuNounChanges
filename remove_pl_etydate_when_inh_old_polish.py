#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  notes = []

  sections, sections_by_lang, _ = blib.split_text_into_sections(text, pagemsg)
  pl_sec = sections_by_lang.get("Polish", None)
  opl_sec = sections_by_lang.get("Old Polish", None)
  if pl_sec is None or opl_sec is None:
    pagemsg("Skipping because didn't find both Polish and Old Polish")
    return

  if "{{etydate|" not in sections[pl_sec]:
    pagemsg("Skipping because no {{etydate}} in Polish section")
    return

  pl_secbody, pl_sectail = blib.split_trailing_separator_and_categories(sections[pl_sec])
  pl_secbody, pl_sectail = blib.force_two_newlines_in_secbody(pl_secbody, pl_sectail)

  opl_secbody, opl_sectail = blib.split_trailing_separator_and_categories(sections[opl_sec])
  opl_secbody, opl_sectail = blib.force_two_newlines_in_secbody(opl_secbody, opl_sectail)

  pl_subsections, pl_subsections_by_header, pl_subsection_levels = blib.split_text_into_subsections(pl_secbody, pagemsg)
  opl_subsections, opl_subsections_by_header, opl_subsection_levels = blib.split_text_into_subsections(
      opl_secbody, pagemsg)

  if "Etymology 1" in pl_subsections_by_header:
    pagemsg("WARNING: Skipping Polish section with {{etydate}} and ==Etymology 1==, can't handle yet")
    return

  if "Etymology" not in pl_subsections_by_header:
    pagemsg("WARNING: Something strange, saw {{etydate}} without ==Etymology==")
    return

  if len(pl_subsections_by_header["Etymology"]) > 1:
    pagemsg("WARNING: Something strange, saw multiple ==Etymology== sections")
    return

  pl_etym_sec = pl_subsections[pl_subsections_by_header["Etymology"][0]]
  if "{{etydate|" not in pl_etym_sec:
    pagemsg("WARNING: Something strange, {{etydate}} not found ==Etymology== but found outside")
    return

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
  
parser = blib.create_argparser("Remove {{etydate}} from Polish etymologies when inherited from Old Polish", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_cats=["Polish lemmas"], skip_ignorable_pages=True)
