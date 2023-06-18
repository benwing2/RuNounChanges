#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  retval = blib.find_modifiable_lang_section(text, "Hungarian", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Hungarian section")
    return
  sections, j, secbody, sectail, has_non_lang = retval
  parsed = blib.parse_text(secbody)
  saw_mpos_inflection_of = False
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "inflection of":
      if getparam(t, "1") != "hu":
        pagemsg("WARNING: Saw non-Hungarian {{inflection of}}, skipping")
        return
      for i in range(4, 30):
        if getparam(t, str(i)) == "(single possession)":
          t.add(str(i), "spos")
          notes.append("(single possession) -> spos in {{inflection of|hu}}")
        if getparam(t, str(i)) in ["(multiple possessions)", "(multiple possession)"]:
          t.add(str(i), "mpos")
          notes.append("(multiple possessions) -> mpos in {{inflection of|hu}}")
        if getparam(t, str(i)) == "mpos" and getparam(t, str(i + 1)) == "poss":
          saw_mpos_inflection_of = True
    if tn == "hu-infl-nom" and saw_mpos_inflection_of:
      n = getparam(t, "n")
      if n == "isg":
        pass
      elif n == "sg":
        t.add("n", "isg")
        notes.append("n=sg -> n=isg in {{hu-infl-nom}} in the context of {{inflection of|hu|...|mpos|poss}}")
      else:
        pagemsg("WARNING: Saw strange value n=%s in %s" % (n, str(t)))
    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  secbody = str(parsed)
  if notes and "==Etymology 1==" in secbody:
    pagemsg("WARNING: Would make a change, but saw ==Etymology 1==, skipping")
    return
  sections[j] = secbody + sectail
  text = "".join(sections)
  return text, notes

parser = blib.create_argparser("Correct n=sg -> n=isg in {{hu-infl-nom}} in the context of {{inflection of|hu|...|mpos|poss}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Hungarian terms with a singularia tantum parameter"])
