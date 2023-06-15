#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  retval = blib.find_modifiable_lang_section(text, "Hungarian", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Hungarian section")
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in range(1, len(subsections), 2):
    if ("===Verb===" in subsections[k] and "{{head|hu|verb form" in subsections[k + 1] and
      "{{participle of|hu|" in subsections[k + 1]):
      if args.split_participle:
        newsubsec = re.sub(r"^(#.*\{\{participle of\|hu\|.*)\n(#.*\{\{inflection of\|hu\|.*)\n\n", r"\2\n\1\n\n",
            subsections[k + 1], 0, re.M)
        if newsubsec != subsections[k + 1]:
          notes.append("reorder {{inflection of|hu|...}} before {{participle of|hu|...}}")
          subsections[k + 1] = newsubsec
        elif re.search(r"\{\{participle of\|hu\|.*\{\{inflection of\|hu\|", subsections[k + 1], re.S):
          pagemsg("WARNING: Saw {{participle of|hu|...}} before {{inflection of|hu|...}} with likely usage examples")
          continue
      if args.split_participle and "{{inflection of|hu|" in subsections[k + 1]:
        subsections[k + 1] = re.sub(r"^(#.*\{\{participle of\|hu\|)", r"\n===Participle===\n{{head|hu|participle}}\n\n\1", subsections[k + 1], 0, re.M)
        notes.append("split Hungarian verb form from participle")
      else:
        subsections[k] = subsections[k].replace("===Verb===", "===Participle===")
        subsections[k + 1] = re.sub(r"\{\{head\|hu\|verb form", "{{head|hu|participle", subsections[k + 1])
        notes.append("Hungarian verb form -> participle in section with {{participle of}}")

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Replace Hungarian 'verb form' with 'participle' in participle sections and maybe split verb forms from participles",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--split-participle", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_cats=[
  "Hungarian present participles"],
  edit=True, stdin=True)
