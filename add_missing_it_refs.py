#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
import infltags

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Italian", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  parsed = blib.parse_text(secbody)
  needs_refs = False

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn in ["it-verb", "it-verb-rfc", "it-conj", "it-conj-rfc"]:
      conj = getp("1")
      if "[r:" in conj or "[ref:" in conj:
        pagemsg("Found conjugation template with reference: %s" % str(t))
        needs_refs = True
    elif tn in ["it-IPA", "it-pr"]:
      respelling = getp("1")
      if "<r:" in respelling or "<ref:" in respelling:
        pagemsg("Found pronunciation template with reference: %s" % str(t))
        needs_refs = True

  if needs_refs:
    if re.search(r"(<references\s*/?\s*>|\{\{reflist)", secbody):
      pagemsg("Already saw <references /> or {{reflist}}")
      return

    subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

    saw_references_sec = False
    for k in range(2, len(subsections), 2):
      if re.search(r"^===*\s*References\s*===* *\n", subsections[k - 1]):
        if saw_references_sec:
          pagemsg("WARNING: Saw two ===References=== sections")
        else:
          subsections[k] = subsections[k].rstrip("\n") + "\n<references />\n\n"
          notes.append("add omitted <references /> to existing Italian ===References=== section")
          saw_references_sec = True

    if not saw_references_sec:
      k = len(subsections) - 1
      while k >= 2 and re.search(r"==\s*(Anagrams|Further reading)\s*==", subsections[k - 1]):
        k -= 2
      if k < 2:
        pagemsg("WARNING: No lemma or non-lemma section")
        return
      subsections[k + 1:k + 1] = ["===References===\n", "<references />\n\n"]
      notes.append("add omitted ===References=== section for Italian term")

    secbody = "".join(subsections)

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)
  return text, notes

parser = blib.create_argparser("Add missing ===References=== sections in Italian lemmas",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Italian' and has no ==Italian== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
