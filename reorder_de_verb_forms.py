#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "German", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  if "Etymology 1" in secbody:
    pagemsg("WARNING: Can't handle Etymology 1")
    return

  subsections = re.split("(^===[^=\n]+===\n)", secbody, 0, re.M)

  while True:
    # Look for a participle and move it up.
    for k in range(2, len(subsections), 2):
      if re.search("==Participle==", subsections[k - 1]):
        l = k
        while l > 2 and (re.search("=(Adjective|Adverb)=", subsections[l - 3])
            or re.search("=Verb=", subsections[l - 3]) and re.search(r"\{\{head\|de\|verb form", subsections[l - 2])):
          l -= 2
        if l < k:
          participle_text = subsections[k - 1:k + 1]
          subsections[k - 1:k + 1] = subsections[l - 1:k - 1]
          subsections[l - 1:k - 1] = participle_text
          notes.append("move Participle section above Adjective/Adverb/Verb form sections")
          break

    # Look for a verb form and move it down.
    for k in range(2, len(subsections), 2):
      if re.search("==Verb==", subsections[k - 1]) and re.search(r"\{\{head\|de\|verb form", subsections[k]):
        l = k
        while l < len(subsections) - 2 and re.search("=(Adjective|Adverb|Participle)=", subsections[l + 1]):
          l += 2
        if l > k:
          non_verb_form_text = subsections[k + 1:l + 1]
          subsections[k + 1:l + 1] = subsections[k - 1:k + 1]
          subsections[k - 1:k + 1] = non_verb_form_text
          notes.append("move Verb form section below Adjective/Adverb/Participle sections")
          break

    else: # no break
      break

    continue

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  return text, notes

parser = blib.create_argparser("Reorder German participles to be before adjectives/adverbs/verb forms, and verb forms to be after adjectives/adverbs/participles",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang German' and has no ==German== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
