#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

AC = u"\u0301"

old_bg_conj_to_conj = {
  "bg-conj-1st (kapya)": ["1.3.", "stem-stressed", "need-vn"],
  # "bg-conj-1st (vlyaza)": ["1.1.", "stem-stressed"],
  # "bg-conj-1st (vzema)": ["1.7.", "stem-stressed"],
  "bg-conj-1st (zova)": ["1.2.", "end-stressed", "need-vn"],
  "bg-conj-1st-ae1": ["1.7.", "stem-stressed", "need-vn"],
  "bg-conj-1st-ae2": ["1.6.", "stem-stressed", "need-vn"],
  "bg-conj-1st-doh": ["1.1.", "end-stressed", "need-vn"],
  "bg-conj-1st-ee1": ["1.7.", "stem-stressed"],
  "bg-conj-1st-ee2": ["1.7.", "stem-stressed"],
  # "bg-conj-1st-ee3": ["1.7.", "stem-stressed"],
  "bg-conj-1st-ekoh": ["1.1.", "end-stressed", "need-vn"],
  "bg-conj-1st-ere": ["1.2.", "end-stressed"],
  "bg-conj-1st-gah": ["1.4.", "stem-stressed", "need-vn"],
  "bg-conj-1st-ie/ue": ["1.7.", "stem-stressed"],
  "bg-conj-1st-kah": ["1.4.", "stem-stressed", "need-vn"],
  "bg-conj-1st-nah": ["1.2.", "stem-stressed"],
  "bg-conj-1st-ryah": ["1.5.", "end-stressed"],
  "bg-conj-1st-sah": ["1.4.", "stem-stressed", "need-vn"],
  "bg-conj-1st-soh": ["1.1.", "end-stressed", "need-vn"],
  "bg-conj-1st-toh": ["1.1.", "end-stressed", "need-vn"],
  "bg-conj-1st-yakoh": ["1.1.", "end-stressed", "need-vn"],
  "bg-conj-1st-zah": ["1.4.", "stem-stressed", "need-vn"],
  "bg-conj-2nd (broya)": ["2.1.", "end-stressed"],
  "bg-conj-2nd-ah1": ["2.1.", "end-stressed"],
  "bg-conj-2nd-ah2": ["2.3.", "end-stressed"],
  "bg-conj-2nd-eh1": ["2.1.", "stem-stressed"],
  "bg-conj-2nd-eh2": ["2.1.", "stem-stressed"],
  "bg-conj-2nd-oih": ["2.1.", "end-stressed"],
  "bg-conj-2nd-yah1": ["2.1.", "end-stressed"],
  "bg-conj-2nd-yah2": ["2.2.", "end-stressed"],
  "bg-conj-2nd-yah3": ["2.1.", "stem-stressed"],
  "bg-conj-3rd": ["", "stem-stressed"],
  "bg-conj-3rd-aem": ["", "stem-stressed"],
}

def is_monosyllabic(word):
  return len(re.sub(u"[^аеиоуяюъ]", "", word)) <= 1

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  head = None
  headt = None
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["bg-verb"]:
      if head is None:
        # This is a signal in case of error processing {{bg-verb}}, that we shoul skip
        # processing the next {{bg-conj-*}}.
        head = False
      newhead = getparam(t, "1")
      aspect = getparam(t, "2")
      if not newhead or not aspect:
        pagemsg("WARNING: Missing head or aspect in {{bg-verb}}: %s" % origt)
        continue
      if aspect not in ["impf", "pf", "both"]:
        pagemsg("WARNING: Unrecognized aspect in {{bg-verb}}: %s" % origt)
        continue
      if not is_monosyllabic(newhead) and AC not in newhead:
        pagemsg("WARNING: Head %s missing an accent: %s" % (newhead, origt))
        continue
      if head:
        pagemsg("WARNING: Saw two heads, previous %s and new %s: %s" % (head, newhead, origt))
        head = newhead
        headt = origt
        continue
      head = newhead
      headt = origt
    if tn in old_bg_conj_to_conj:
      if head == False:
        head = None
        continue
      if not head:
        pagemsg("WARNING: No {{bg-verb}} found preceding conjugation: %s" % origt)
        continue
      bg_conj_spec = old_bg_conj_to_conj[tn]
      need_vn = False
      if len(bg_conj_spec) == 3:
        newconj, stress, need_vn = bg_conj_spec
      else:
        newconj, stress = bg_conj_spec
      active = re.sub(u" с[еи]$", "", head)
      ends_in_accent = active.endswith(AC) or is_monosyllabic(active)
      if stress == "end-stressed" and not ends_in_accent or stress == "stem-stressed" and ends_in_accent:
        pagemsg("WARNING: Stress appears wrongly placed in %s, expected %s: %s, %s" % (
          head, stress, headt, origt))
        continue
      conj_aspect = getparam(t, "2")
      if conj_aspect not in ["imp", "perf"]:
        pagemsg("WARNING: Bad conjugation aspect %s: %s, %s" % (conj_aspect, headt, origt))
        continue
      if conj_aspect == "imp" and aspect == "pf" or conj_aspect == "perf" and aspect == "impf":
        pagemsg("WARNING: Conjugation aspect %s disagrees with head aspect %s: %s, %s" % (
          conj_aspect, aspect, headt, origt))
        continue
      if conj_aspect == "perf" and aspect == "both":
        pagemsg("WARNING: Found conjugation aspect perf and head aspect both, probably need to delete the conjugation: %s, %s" % (
          conj_aspect, aspect, headt, origt))
        continue
      transitivity = getparam(t, "3")
      if transitivity not in ["intr", "tr", u"се", u"си"]:
        pagemsg("WARNING: Bad transitivity %s: %s, %s" % (transitivity, headt, origt))
        continue
      if transitivity in [u"се", u"си"]:
        if not head.endswith(" " + transitivity):
          pagemsg("WARNING: Conjugation reflexive %s disagrees with head %s, converting to reflexive: %s, %s" % (
            transitivity, head, headt, origt))
          head += " " + transitivity
        transitivity = ""
      else:
        transitivity = "." + transitivity
      if getparam(t, "4") or getparam(t, "5") or getparam(t, "6"):
        pagemsg("WARNING: Stray param in conjugation template: %s, %s" % (
          headt, origt))
        continue
      if need_vn and aspect != "pf":
        pagemsg("WARNING: Not converting %s, needs manually-specified verbal noun, would convert to {{bg-conj|%s<%s%s%s>}}: %s, %s" %
            (head, head, newconj, aspect, transitivity, headt, origt))
        continue
      blib.set_template_name(t, "bg-conj")
      rmparam(t, "3")
      rmparam(t, "2")
      rmparam(t, "1")
      t.add("1", "%s<%s%s%s>" % (head, newconj, aspect, transitivity))
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("convert %s to %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser(u"Convert Bulgarian verb conjugations to new {{bg-conj}}",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Bulgarian verbs"], edit=True)
