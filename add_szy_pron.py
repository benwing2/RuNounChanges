#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

pronun_templates = ["IPA", "szy-IPA"]

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Sakizaya", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  parsed = blib.parse_text(secbody)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in pronun_templates:
      pagemsg("Already saw pronunciation template: %s" % str(t))
      return

  def construct_new_pron_template():
    return "{{szy-IPA}}", ""

  def insert_new_l3_pron_section(k):
    new_pron_template, pron_prefix = construct_new_pron_template()
    subsections[k:k] = ["===Pronunciation===\n", pron_prefix + new_pron_template + "\n\n"]
    notes.append("add top-level Sakizaya pron %s" % new_pron_template)

  k = 2
  while k < len(subsections) and re.search("==(Alternative forms|Etymology)==", subsections[k - 1]):
    k += 2
  if k -1 >= len(subsections):
    pagemsg("WARNING: No lemma or non-lemma section at top level")
    return
  insert_new_l3_pron_section(k - 1)

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Add Sakizaya pronunciations", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_cats=["Sakizaya lemmas"], edit=True, stdin=True)

blib.elapsed_time()
