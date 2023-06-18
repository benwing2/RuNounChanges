#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

no_split_etym = {
  "arroge",
  "arrogi",
  "glissando",
}

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

  notes = []

  if pagetitle in no_split_etym:
    pagemsg("Not splitting etymologies because page listed in no_split_etym")
    return

  if "{{head|it|verb form}}" not in secbody:
    pagemsg("Didn't see verb form")
    return

  if re.search(r"\{\{it-verb[|}]", secbody) or "{{it-conj" in secbody:
    pagemsg("WARNING: Saw both verb and verb form in same term")
    return

  # Anagrams and such go after all etym sections and remain as such even if we start with non-etym-split text
  # and end with multiple etym sections.
  l3_secs = re.split("(^===[^=\n]+===\n)", secbody, 0, re.M)
  for last_included_sec in range(len(l3_secs) - 1, 0, -2):
    if not re.search(r"^===\s*(References|See also|Derived terms|Related terms|Further reading|Anagrams)\s*=== *\n",
        l3_secs[last_included_sec - 1]):
      break

  for first_l3_sec in range(2, last_included_sec + 2, 2):
    if not re.search(r"^===\s*(Etymology|Pronunciation|Alternative forms)\s*=== *\n",
        l3_secs[first_l3_sec - 1]):
      break

  verb_form_sec = None
  for k in range(first_l3_sec, last_included_sec + 2, 2):
    if re.search(r"^===\s*Verb\s*=== *\n", l3_secs[k - 1]):
      if "{{head|it|verb form}}" not in l3_secs[k]:
        pagemsg("WARNING: Saw ==Verb== without verb-form header in section %s" % (k // 2 + 1))
        return
      # Skip e.g. [[affittasi]], [[affittansi]], where the noun is directly derived from the compound form.
      if "{{it-compound of" in l3_secs[k]:
        pagemsg("WARNING: Saw verb-form section with {{it-compound of}} in section %s, skipping" % (k // 2 + 1))
        return
      if verb_form_sec is not None:
        pagemsg("WARNING: Saw two verb-form sections %s and %s" % (verb_form_sec // 2 + 1, k // 2 + 1))
        return
      verb_form_sec = k
    elif not re.search(r"^===\s*(Noun|Adjective)\s*=== *\n", l3_secs[k - 1]):
      if re.search(r"^===\s*Etymology [0-9]+\s*=== *\n", l3_secs[k - 1]):
        pagemsg("Already saw multiple Etymology sections, skipping")
        return
      else:
        pagemsg("WARNING: Saw unrecognized header %s in section %s" % (l3_secs[k - 1].strip(), k // 2 + 1))
        return
  if verb_form_sec == last_included_sec:
    pass
  elif verb_form_sec == first_l3_sec:
    # Swap verb-form section with remaining sections
    l3_secs[first_l3_sec - 1: last_included_sec + 1] = (
      l3_secs[first_l3_sec + 1: last_included_sec + 1] + l3_secs[first_l3_sec - 1: first_l3_sec + 1]
    )
    notes.append("move Italian verb-form section last")
  else:
    pagemsg("WARNING: Saw verb form section not first or last among part-of-speech sections")
    return

  if re.search(r"^====\s*(Derived terms|Related terms)\s*==== *\n", l3_secs[last_included_sec], re.M):
    # Move these to level 3.
    l3_secs[last_included_sec] = re.sub(r"^=(===\s*(Derived terms|Related terms)\s*===)= *\n", r"\1" + "\n",
        l3_secs[last_included_sec], 0, re.M)
    verb_l3_secs = re.split("(^===[^=\n]+===\n)", l3_secs[last_included_sec], 0, re.M)
    l3_secs[last_included_sec] = verb_l3_secs[0]
    l3_secs[last_included_sec + 1: last_included_sec + 1] = verb_l3_secs[1:]
    notes.append("move ==Derived/Related terms== under Italian verb form to L3")

  text_before_etym_sections = []
  split_etym_sections = []
  saw_pronunciation = False
  saw_etymology = False
  goes_at_top_of_first_etym_section = "\n"

  def indent_subsections_by_one(subsectext):
    return re.sub("^(==.*==)$", r"=\1=", subsectext, 0, re.M)

  split_etym_sections.append("===Etymology 1===\n")
  for k in range(2, last_included_sec + 2, 2):
    if "=Pronunciation=" in l3_secs[k - 1]:
      if saw_pronunciation:
        pagemsg("WARNING: Saw two ===Pronunciation=== sections at L3")
        return
      saw_pronunciation = True
      text_before_etym_sections.append(l3_secs[k - 1])
      text_before_etym_sections.append(l3_secs[k])
    elif "=Etymology=" in l3_secs[k - 1]:
      if saw_etymology:
        pagemsg("WARNING: Saw two ===Etymology=== sections at L3")
        return
      saw_etymology = True
      goes_at_top_of_first_etym_section = l3_secs[k]
    else:
      if "=Verb=" in l3_secs[k - 1]:
        split_etym_sections.append("===Etymology 2===\n")
        split_etym_sections.append("{{nonlemma}}\n\n")
      split_etym_sections.append(indent_subsections_by_one(l3_secs[k - 1]))
      split_etym_sections.append(indent_subsections_by_one(l3_secs[k]))

  split_etym_sections[1:1] = [goes_at_top_of_first_etym_section]
  sec_zero_text = l3_secs[0].strip()
  if sec_zero_text:
    split_etym_sections[1:1] = [sec_zero_text + "\n"]
  l3_secs[0] = "\n"
  split_etym_sections[0:0] = text_before_etym_sections
  l3_secs[1: last_included_sec + 1] = split_etym_sections
  notes.append("split Italian verb form and other meanings into separate Etymology sections")

  secbody = "".join(l3_secs)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  return text, notes

parser = blib.create_argparser("Split Italian verb forms into separate Etymology section",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Italian' and has no ==Italian== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
