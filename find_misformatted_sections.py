#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

# FIXME: Declension before Derived terms etc.
# FIXME: Better handling of Alternative Forms

lemma_poses = {
  "adjective",
  "adverb",
  "cardinal number",
  "circumfix",
  "conjunction",
  "determiner",
  "diacritical mark",
  "gerund",
  "idiom",
  "interfix",
  "interjection",
  "letter",
  "noun",
  "numeral",
  "particle",
  "participle",
  "phrase",
  "predicative",
  "prefix",
  "preposition",
  "prepositional phrase",
  "pronoun",
  "proper noun",
  "proverb",
  "punctuation mark",
  "suffix",
  "verb",
}

capitalized_lemma_poses = [k.capitalize() for k in lemma_poses]
pos_regex = "==(%s)==" % "|".join(capitalized_lemma_poses)

last_etym_header = None

def check_for_bad_etym_sections(secbody, pagemsg):
  global args
  l3_subsections = re.split(r"(^===[^=\n]+=== *\n)", secbody, 0, re.M)
  subsections = re.split(r"(^===+[^=\n]+===+ *\n)", secbody, 0, re.M)
  global last_etym_header
  l3_last_etym_header = len(l3_subsections) - 2
  last_etym_header = len(subsections) - 2

  if len(l3_subsections) < 3:
    pagemsg("WARNING: Something wrong, didn't see three subsections")
    return

  if re.search(r"==\s*Pronunciation 1\s*==", secbody):
    pagemsg("WARNING: Saw Pronunciation 1")
    return

  if re.search(r"==\s*Etymology [0-9]+\s*==", secbody) and not re.search(r"==\s*Etymology 1\s*==", secbody):
    pagemsg("WARNING: Has ==Etymology N== but not ==Etymology 1==")
    return

  if not re.search(r"==\s*Etymology 1\s*==", secbody):
    return

  if not re.search(r"==\s*Etymology 2\s*==", secbody):
    pagemsg("WARNING: Has ==Etymology 1== but not ==Etymology 2==")
    return

  l3_first_etym_header = 1
  while re.search(r"^===\s*(Alternative forms|Pronunciation)\s*=== *\n", l3_subsections[l3_first_etym_header]):
    l3_first_etym_header += 2
  final_section_re = r"^===\s*(References|See also|Derived terms|Related terms|Further reading|Anagrams)\s*=== *\n"
  while l3_last_etym_header > 1:
    if re.search(final_section_re, l3_subsections[l3_last_etym_header]):
      l3_last_etym_header -= 2
    else:
      break
  while last_etym_header > 1:
    if re.search(final_section_re, subsections[last_etym_header]):
      last_etym_header -= 2
    else:
      break
  expected_etym_no = 1
  for k in xrange(l3_first_etym_header, l3_last_etym_header + 2, 2):
    if not re.search(r"===\s*Etymology %s\s*=== *\n" % expected_etym_no, l3_subsections[k]):
      pagemsg("WARNING: Expected ===Etymology %s=== but saw %s in section %s" % (
        expected_etym_no, l3_subsections[k].strip(), k // 2 + 1))
    expected_etym_no += 1

def check_for_bad_subsections(secbody, pagemsg):
  global args
  notes = []
  subsections = re.split(r"(^===+[^=\n]+===+ *\n)", secbody, 0, re.M)
  indentation = {}
  def correct_indentation(k, expected_indentation):
    if args.correct:
      m = re.match("^(=+)(.*?)(=+) *\n", subsections[k])
      if m and len(m.group(1)) == len(m.group(3)):
        subsections[k] = ("=" * expected_indentation) + m.group(2) + ("=" * expected_indentation) + "\n"
        indentation[k] = expected_indentation
        notes.append("correct indentation of %s to %s" % (m.group(2).strip(), expected_indentation))
  for k in xrange(2, len(subsections), 2):
    if re.search("^==", subsections[k], re.M):
      pagemsg("WARNING: Saw badly formatted section header in section %s" % (k // 2))
  for k in xrange(1, len(subsections), 2):
    if re.search(r"===+ +\n", subsections[k]):
      pagemsg("WARNING: Space at end of section header in section %s" % (k // 2 + 1))
      if args.correct:
        subsections[k] = re.sub(r"(===+) +(\n)", r"\1\2", subsections[k])
        notes.append("remove extraneous space at end of section header")
    if re.search(r"^===+ ", subsections[k]) or re.search(" ==+ *\n", subsections[k]):
      pagemsg("WARNING: Space surrounding section name in section header in section %s" % (k // 2 + 1))
      if args.correct:
        subsections[k] = re.sub(r"^(===+)\s*(.*?)\s*(===+\n)", r"\1\2\3", subsections[k])
        notes.append("remove extraneous space surrounding section name in section header")
    m = re.match("^(=+).*?(=+) *\n", subsections[k])
    indentation[k] = len(m.group(1))
    if indentation[k] != len(m.group(2)):
      pagemsg("WARNING: Mismatched indentation, %s equal signs on left but %s on right in section %s" % (indentation[k], len(m.group(2)), k // 2 + 1))
  for k in xrange(1, len(subsections) - 2, 2):
    if re.search(r"=\s*Pronunciation\s*=", subsections[k]) and re.search(r"=\s*Etymology\s*=", subsections[k + 2]):
      pagemsg("WARNING: Pronunciation before Etymology in section %s" % (k // 2 + 1))
      if args.correct:
        pronheader = subsections[k]
        proncontents = subsections[k + 1]
        subsections[k] = subsections[k + 2]
        subsections[k + 1] = subsections[k + 3]
        subsections[k + 2] = pronheader
        subsections[k + 3] = proncontents
        notes.append("switch Pronunciation and Etymology sections")
  for k in xrange(3, len(subsections), 2):
    if indentation[k] - indentation[k - 2] > 1:
      pagemsg("WARNING: Increase in %s from %s to %s in indentation level in section %s: %s, %s" % (
        indentation[k] - indentation[k - 2], indentation[k - 2],
        indentation[k], k // 2 + 1, subsections[k - 2].strip(), subsections[k].strip()
      ))
  has_etym_sections = re.search(r"==\s*Etymology 1\s*==", secbody)
  for k in xrange(1, len(subsections), 2):
    if re.search(r"=\s*(Conjugation|Declension|Inflection)\s*=", subsections[k]):
      expected_indentation = 4 + (1 if has_etym_sections else 0)
      if indentation[k] != expected_indentation:
        pagemsg("WARNING: Expected %s with indentation %s but actually has %s in section %s" % (
          subsections[k].strip(), expected_indentation, indentation[k], k // 2 + 1))
        if args.correct:
          # Check to see if there are two or more POS headers before section; if so, don't do anything because
          # we might have a case where the declension is at the end and needs to be duplicated.
          num_pos_sections = 0
          for j in xrange(1, k, 2):
            if re.search(pos_regex, subsections[j]):
              num_pos_sections += 1
          if num_pos_sections > 1:
            pagemsg("WARNING: Can't correct %s header because it was %s POS sections (> 1) above it" % (
              subsections[k].strip(), num_pos_sections))
          else:
            correct_indentation(k, expected_indentation)
      if k < len(subsections) - 2 and indentation[k + 2] > indentation[k]:
        pagemsg("WARNING: %s section has nested section %s under it in section %s" % (
          subsections[k].strip(), subsections[k + 2].strip(), k // 2 + 1))
  for k in xrange(1, len(subsections), 2):
    if re.search(r"=\s*(Synonyms|Antonyms|Hyponyms|Hypernyms|Coordinate terms|Derived terms|Related terms|Descendants|Usage notes)\s*=", subsections[k]):
      if re.search(r"=\s*(Derived terms|Related terms)\s*=", subsections[k]) and k > last_etym_header:
        continue
      expected_indentation = 4 + (1 if has_etym_sections else 0)
      if indentation[k] != expected_indentation:
        pagemsg("WARNING: Expected %s with indentation %s but actually has %s in section %s" % (
          subsections[k].strip(), expected_indentation, indentation[k], k // 2 + 1))
        correct_indentation(k, expected_indentation)
      if k < len(subsections) - 2 and indentation[k + 2] > indentation[k]:
        pagemsg("WARNING: %s section has nested section %s under it in section %s" % (
          subsections[k].strip(), subsections[k + 2].strip(), k // 2 + 1))
  beginning_of_etym_sections = None
  if has_etym_sections:
    for k in xrange(1, len(subsections), 2):
      if re.search(r"==\s*Etymology 1\s*==", subsections[k]):
        beginning_of_etym_sections = k
        break
    if not beginning_of_etym_sections:
      pagemsg("WARNING: Something weird, ==Etymology 1== in text but can't find section with this header")
      beginning_of_etym_sections = 1
  else:
    beginning_of_etym_sections = len(subsections)
  expected_pron_indentation = 3
  expected_altform_indentation = 3
  for k in xrange(1, len(subsections), 2):
    check_correct = False
    if re.search(r"==\s*Etymology [0-9]+\s*==", subsections[k]):
      expected_pron_indentation = 4
      expected_altform_indentation = 4
    if re.search(pos_regex, subsections[k]):
      if has_etym_sections and k < beginning_of_etym_sections:
        pagemsg("WARNING: Saw POS header %s before beginning of multi-etym sections in section %s" % (
          subsections[k].strip(), k // 2 + 1))
      expected_altform_indentation = 5 if has_etym_sections else 4
      expected_indentation = 4 if has_etym_sections else 3
      check_correct = True
    if re.search(r"==\s*Alternative forms\s*==", subsections[k]):
      expected_indentation = expected_altform_indentation
      check_correct = True
    if re.search(r"==\s*Pronunciation\s*==", subsections[k]):
      expected_indentation = expected_pron_indentation
      check_correct = True
    if check_correct and expected_indentation != indentation[k]:
      pagemsg("WARNING: Saw %s at level %s but expected %s in section %s" % (
        subsections[k].strip(), indentation[k], expected_indentation, k // 2 + 1))
      correct_indentation(k, expected_indentation)
  return "".join(subsections), notes

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  check_for_bad_etym_sections(text, pagemsg)
  return check_for_bad_subsections(text, pagemsg)

parser = blib.create_argparser("Find misformatted sections of various sorts; should be run on language-specific output from find_regex.py",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--correct", action="store_true", help="Correct errors as much as possible.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, stdin=True, edit=True)
