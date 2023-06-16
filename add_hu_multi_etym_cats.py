#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from collections import defaultdict
import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

hu_lemma_template_mapping = {
  "hu-noun": "noun",
  "hu-verb": "verb",
  "hu-adj": "adjective",
  "hu-adv": "adverb",
  "hu-pron": "pronoun",
  "hu-letter": "letter"
}
hu_lemmas = ["adjective", "adverb", "article", "conjunction", "determiner",
  "interjection", "letter", "noun", "numeral", "particle", "phrase",
  "postposition", "pronoun", "proper noun", "verb", "suffix", "prefix",
  "interfix", "clitic"]
hu_lemma_mapping = {
  "suffix": "morpheme",
  "prefix": "morpheme",
  "interfix": "morpheme",
  "clitic": "morpheme"
}
hu_nonlemma_forms = ["adjective form", "adverb form", "determiner form",
    "noun form", "numeral form", "pronoun form", "verb form"]
hu_pages_seen = set()
hu_pos_pos_pairs = defaultdict(int)

def add_category(secbody, sectail, pagemsg, notes, cat):
  separator = ""
  m = re.match(r"^(.*?\n)(\n*--+\n*)$", sectail, re.S)
  if m:
    sectail, separator = m.groups()
  if re.search(r"\[\[Category:%s(\||\])" % re.escape(cat), secbody + sectail):
    # Category already present
    pagemsg("Category 'Hungarian %s' already present" % cat)
    return secbody, sectail + separator
  parsed = blib.parse_text(secbody + sectail)
  for t in parsed.filter_templates():
    if tname(t) in ["cln", "catlangname"] and getparam(t, "1") == "hu":
      for i in range(2, 30):
        if getparam(t, str(i)) == cat:
          # Category already present in templatized form
          pagemsg("Category 'Hungarian %s' already present" % cat)
          return secbody, sectail + separator

  # Now add the category to existing {{cln}}, or create one.
  parsed = blib.parse_text(sectail)
  for t in parsed.filter_templates():
    if tname(t) in ["cln", "catlangname"] and getparam(t, "1") == "hu":
      for i in range(2, 30):
        if not getparam(t, str(i)):
          break
      else: # no break
        pagemsg("WARNING: Something strange, reached 30= in %s and didn't see place to insert" % str(t))
        return secbody, sectail + separator
      before = str(i + 1) if getparam(t, str(i + 1)) else "sort" if getparam(t, "sort") else None
      origt = str(t)
      t.add(str(i), cat, before=before)
      notes.append("insert '%s' into existing {{%s|hu}}" % (cat, tname(t)))
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      return secbody, str(parsed) + separator
  # Need to create {{cln}}.
  newtext = "{{cln|hu|%s}}" % cat
  sectail = sectail.strip()
  if sectail:
    sectail = sectail + "\n" + newtext
  else:
    sectail = newtext
  notes.append("add %s" % newtext)
  pagemsg("Added %s" % newtext)
  return secbody.rstrip("\n") + "\n", "\n" + sectail + "\n\n" + separator.lstrip("\n")

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if pagetitle in hu_pages_seen:
    pagemsg("Skipping because already seen")
    return
  hu_pages_seen.add(pagetitle)
  pagemsg("Processing")

  retval = blib.find_modifiable_lang_section(text, "Hungarian", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Hungarian section")
    return
  sections, j, secbody, sectail, has_non_lang = retval
  if "==Etymology 1==" not in secbody:
    return
  etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
  if len(etym_sections) < 5:
    pagemsg("WARNING: Not enough etym sections, found %s, expected >= 5" %
        len(etym_sections))
    return
  num_lemmas = 0
  num_nonlemma_forms = 0
  poses_seen_per_section = defaultdict(set)
  for k in range(2, len(etym_sections), 2):
    section = etym_sections[k]
    parsed = blib.parse_text(section)
    saw_lemma = False
    saw_nonlemma_form = False
    for t in parsed.filter_templates():
      tn = tname(t)
      p2 = getparam(t, "2")
      recording_lemma = None
      if tn in hu_lemma_template_mapping:
        recording_lemma = hu_lemma_template_mapping[tn]
      elif tn == "head" and getparam(t, "1") == "hu" and p2 in hu_lemmas:
        recording_lemma = hu_lemma_mapping.get(p2, p2)
      elif tn == "head" and getparam(t, "1") == "hu" and p2 and p2[-1] == "s" and p2[:-1] in hu_lemmas:
        recording_lemma = hu_lemma_mapping.get(p2[:-1], p2[:-1])
      if recording_lemma:
        poses_seen_per_section[k // 2 - 1].add(recording_lemma)
        if not saw_lemma:
          num_lemmas += 1
          saw_lemma = True
      recording_nonlemma_form = None
      if tn == "head" and getparam(t, "1") == "hu" and p2 in hu_nonlemma_forms:
        recording_nonlemma_form = p2
      elif tn == "head" and getparam(t, "1") == "hu" and p2 and p2[-1] == "s" and p2[:-1] in hu_nonlemma_forms:
        recording_nonlemma_form = p2[:-1]
      if recording_nonlemma_form:
        poses_seen_per_section[k // 2 - 1].add(recording_nonlemma_form)
        if not saw_nonlemma_form:
          num_nonlemma_forms += 1
          saw_nonlemma_form = True
    if not saw_lemma and not saw_nonlemma_form:
      pagemsg("WARNING: In %s, didn't see lemma or non-lemma" % etym_sections[k - 1].strip())
  pagemsg("Saw num_lemmas=%s, num_nonlemma_forms=%s" % (num_lemmas, num_nonlemma_forms))
  if num_lemmas and num_nonlemma_forms:
    secbody, sectail = add_category(secbody, sectail, pagemsg, notes,
      "terms with lemma and non-lemma form etymologies")
  if num_lemmas > 1:
    secbody, sectail = add_category(secbody, sectail, pagemsg, notes,
      "terms with multiple lemma etymologies")
  if num_nonlemma_forms > 1:
    secbody, sectail = add_category(secbody, sectail, pagemsg, notes,
      "terms with multiple non-lemma form etymologies")
  pairs_seen = set()
  for k in range((len(etym_sections) - 1) // 2):
    for l in range(k + 1, (len(etym_sections) - 1) // 2):
      for posk in poses_seen_per_section[k]:
        for posl in poses_seen_per_section[l]:
          if posk in hu_nonlemma_forms and posl in hu_lemmas:
            pairs_seen.add((posl, posk))
          elif ((posk in hu_lemmas and posl in hu_lemmas or
              posk in hu_nonlemma_forms and posl in hu_nonlemma_forms) and
              posk > posl):
            pairs_seen.add((posl, posk))
          else:
            pairs_seen.add((posk, posl))
  pagemsg(
    "; ".join("%s: %s" % (sec + 1, ",".join(poses))
    for sec, poses in sorted(poses_seen_per_section.items(), key=lambda x:x[0])
  ))
  for posk, posl in pairs_seen:
    hu_pos_pos_pairs[(posk, posl)] += 1
    if posk == posl:
      secbody, sectail = add_category(secbody, sectail, pagemsg, notes,
        "terms with multiple %s etymologies" % posk)
    else:
      secbody, sectail = add_category(secbody, sectail, pagemsg, notes,
        "terms with %s and %s etymologies" % (posk, posl))
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser(u"Add multi-lemma categories to Hungarian terms",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_cats=["Hungarian lemmas", "Hungarian non-lemma forms"], edit=True, stdin=True)

for pair, count in sorted(hu_pos_pos_pairs.items(), key=lambda x:-x[1]):
  msg("| %s || %s || %s" % (pair[0], pair[1], count))
  msg("|-")
