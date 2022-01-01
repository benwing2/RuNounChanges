#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site
from collections import defaultdict

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
  "root",
  "suffix",
  "verb",
}

capitalized_lemma_poses = [k.capitalize() for k in lemma_poses]
pos_regex = "==(%s)==" % "|".join(capitalized_lemma_poses)

def get_subsection_id(subsections, k, include_equal_signs=False):
  if k == 0:
    return "0"
  if k % 2 == 0:
    k -= 1
  if include_equal_signs:
    subsection_name = subsections[k].strip()
  else:
    m = re.match("^=+(.*?)=+ *\n", subsections[k])
    subsection_name = m.group(1).strip() if m else "UNKNOWN SECTION NAME"
  return "%s (%s)" % (k // 2 + 1, subsection_name)

def check_for_bad_etym_sections(secbody, pagemsg):
  global args
  l3_subsections = re.split(r"(^===[^=\n]+=== *\n)", secbody, 0, re.M)
  subsections = re.split(r"(^===+[^=\n]+===+ *\n)", secbody, 0, re.M)
  l3_last_etym_header = len(l3_subsections) - 2

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
  final_section_re = r"^===\s*(References|See also|Derived terms|Related terms|Conjugation|Declension|Inflection|Descendants|Further reading|Anagrams|Mutation)\s*=== *\n"
  while l3_last_etym_header > 1:
    if re.search(final_section_re, l3_subsections[l3_last_etym_header]):
      l3_last_etym_header -= 2
    else:
      break
  expected_etym_no = 1
  for k in xrange(l3_first_etym_header, l3_last_etym_header + 2, 2):
    if not re.search(r"===\s*Etymology %s\s*=== *\n" % expected_etym_no, l3_subsections[k]):
      pagemsg("WARNING: Expected ===Etymology %s=== but saw section %s" % (
        expected_etym_no, get_subsection_id(l3_subsections, k, include_equal_signs=True)))
    expected_etym_no += 1

def group_correction_notes(template, notes):
  if len(notes) == 0:
    return ""
  if len(notes) == 1:
    notetext = notes[0]
  elif len(notes) == 2:
    notetext = "%s and %s" % (notes[0], notes[1])
  else:
    notetext = "%s and %s" % (", ".join(notes[0:-1]), notes[-1])
  return template % notetext

def check_for_bad_subsections(secbody, pagemsg, langname):
  global args
  notes = []
  def append_note(note):
    if langname:
      notes.append("%s: %s" % (langname, note))
    else:
      notes.append(note)
  subsections = re.split(r"(^===+[^=\n]+===+ *\n)", secbody, 0, re.M)
  def subsection_id(k, include_equal_signs=False):
    return get_subsection_id(subsections, k, include_equal_signs=include_equal_signs)

  correct_whitespace_notes = []
  for k in xrange(0, len(subsections), 2):
    if not subsections[k].strip():
      newsubseck = "\n"
      if newsubseck != subsections[k]:
        pagemsg("WARNING: Empty section %s does not consist of a single newline" % subsection_id(k))
        if args.correct:
          subsections[k] = newsubseck
          correct_whitespace_notes.append("section %s" % subsection_id(k))
    else:
      newsubseck = subsections[k].lstrip()
      if newsubseck != subsections[k]:
        pagemsg("WARNING: Section %s begins with whitespace" % subsection_id(k))
        if args.correct:
          subsections[k] = newsubseck
          correct_whitespace_notes.append("section %s" % subsection_id(k))
      if not subsections[k].endswith("\n\n"):
        pagemsg("WARNING: Section %s does not end in two newlines" % subsection_id(k))
        if args.correct:
          subsections[k] = subsections[k].rstrip() + "\n\n"
          if k == len(subsections) - 1 and re.search("^--+$", subsections[k], re.M):
            append_note("correct whitespace after final language divider")
          else:
            correct_whitespace_notes.append("section %s" % subsection_id(k))
  if len(correct_whitespace_notes) > 0:
    append_note(group_correction_notes("correct whitespace of %s", correct_whitespace_notes))

  correct_indentation_notes = []
  indentation = {}
  def correct_indentation(k, expected_indentation):
    if args.correct:
      m = re.match("^(=+)(.*?)(=+) *\n", subsections[k])
      if m and len(m.group(1)) == len(m.group(3)):
        subsections[k] = ("=" * expected_indentation) + m.group(2) + ("=" * expected_indentation) + "\n"
        indentation[k] = expected_indentation
        correct_indentation_notes.append("section %s to %s" % (subsection_id(k), expected_indentation))
  for k in xrange(2, len(subsections), 2):
    if re.search("^==", subsections[k], re.M):
      pagemsg("WARNING: Saw badly formatted section header in section %s <%s>" % (subsection_id(k), subsections[k].strip()))
  for k in xrange(1, len(subsections), 2):
    if re.search(r"===+ +\n", subsections[k]):
      pagemsg("WARNING: Space at end of section header in section %s" % subsection_id(k))
      if args.correct:
        subsections[k] = re.sub(r"(===+) +(\n)", r"\1\2", subsections[k])
        append_note("remove extraneous space at end of section header in section %s" % subsection_id(k))
    if re.search(r"^===+ ", subsections[k]) or re.search(" ==+ *\n", subsections[k]):
      pagemsg("WARNING: Space surrounding section name in section header in section %s" % subsection_id(k))
      if args.correct:
        subsections[k] = re.sub(r"^(===+)\s*(.*?)\s*(===+\n)", r"\1\2\3", subsections[k])
        append_note("remove extraneous space surrounding section header name in section %s" % subsection_id(k))
    m = re.match("^(=+).*?(=+) *\n", subsections[k])
    indentation[k] = len(m.group(1))
    if indentation[k] != len(m.group(2)):
      pagemsg("WARNING: Mismatched indentation, %s equal signs on left but %s on right in section %s"
          % (indentation[k], len(m.group(2)), subsection_id(k)))
  for k in xrange(1, len(subsections) - 2, 2):
    if re.search(r"=\s*Pronunciation\s*=", subsections[k]) and re.search(r"=\s*Etymology\s*=", subsections[k + 2]):
      pagemsg("WARNING: Pronunciation before Etymology in section %s" % subsection_id(k))
      if args.correct:
        pronheader = subsections[k]
        proncontents = subsections[k + 1]
        subsections[k] = subsections[k + 2]
        subsections[k + 1] = subsections[k + 3]
        subsections[k + 2] = pronheader
        subsections[k + 3] = proncontents
        append_note("switch Pronunciation and Etymology sections")
  for k in xrange(3, len(subsections), 2):
    if indentation[k] - indentation[k - 2] > 1:
      pagemsg("WARNING: Increase in %s from %s to %s in indentation level from section %s to section %s" % (
        indentation[k] - indentation[k - 2], indentation[k - 2],
        indentation[k], subsection_id(k - 2), subsection_id(k)
      ))
  has_etym_sections = re.search(r"==\s*Etymology 1\s*==", secbody)
  last_etym_header = 0
  if has_etym_sections:
    for k in xrange(1, len(subsections), 2):
      if re.search(r"=\s*Etymology [0-9]", subsections[k]):
        last_etym_header = k
  pos_since_etym_section = 0
  headers_that_may_appear_at_same_level_as_two_poses_regex = "=\s*(Derived terms|Related terms|Conjugation|Declension|Inflection|Descendants)\s*="
  headers_seen = defaultdict(int)
  headers_seen_since_etym_section = defaultdict(int)
  for k in xrange(1, len(subsections), 2):
    if re.search(r"=\s*Etymology [0-9]", subsections[k]):
      pos_since_etym_section = 0
      headers_seen_since_etym_section = defaultdict(int)
    if re.search(pos_regex, subsections[k]):
      pos_since_etym_section += 1
    m = re.search(headers_that_may_appear_at_same_level_as_two_poses_regex, subsections[k])
    if m:
      headers_seen_since_etym_section[m.group(1)] += 1
      headers_seen[m.group(1)] += 1
    if re.search(r"=\s*(Synonyms|Antonyms|Hyponyms|Hypernyms|Coordinate terms|Derived terms|Related terms|Descendants|Usage notes|Conjugation|Declension|Inflection)\s*=", subsections[k]):
      expected_indentation = 4 + (1 if has_etym_sections else 0)
      if indentation[k] != expected_indentation:
        pagemsg("WARNING: Expected indentation %s but actually has %s in section %s"
          % (expected_indentation, indentation[k], subsection_id(k)))
        m = re.search(headers_that_may_appear_at_same_level_as_two_poses_regex, subsections[k])
        if m and pos_since_etym_section > 1 and headers_seen_since_etym_section[m.group(1)] <= 1 and expected_indentation > indentation[k]:
          if args.correct:
            # We could legitimately have one Declension/Descendants/etc. section corresponding to two or more POS's and
            # at the same level as the POS's; but presumably not if we've seen another of the same header in the same
            # etym section.
            pagemsg("WARNING: Can't correct section %s header (first such header in etym section) because it has %s POS sections (> 1) in etym section above it and indentation is increasing" % (
              subsection_id(k), pos_since_etym_section))
        elif m and has_etym_sections and k > last_etym_header and headers_seen[m.group(1)] <=1 and indentation[k] == 3:
          # We could legitimately have one L3 Declension/Descendants/etc. section corresponding to two or more POS's in
          # different etym sections (i.e. covering all etym sections); but presumably not if we've seen another of the
          # same header.
          if args.correct:
            pagemsg("WARNING: Can't correct L3 section %s header (first such header seen) because there is more than one etym section and it is past the last one" % (
              subsection_id(k)))
        else:
          correct_indentation(k, expected_indentation)
      if k < len(subsections) - 2 and indentation[k + 2] > indentation[k]:
        pagemsg("WARNING: nested section %s under section %s"
          % (subsection_id(k + 2, include_equal_signs=True), subsection_id(k, include_equal_signs=True)))
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
  dont_correct_until_etym_header = False
  for k in xrange(1, len(subsections), 2):
    check_correct = False
    if re.search(r"==\s*Etymology [0-9]+\s*==", subsections[k]):
      expected_pron_indentation = 4
      expected_altform_indentation = 4
      dont_correct_until_etym_header = False
    if dont_correct_until_etym_header:
      continue
    if re.search(pos_regex, subsections[k]):
      if has_etym_sections and k < beginning_of_etym_sections:
        pagemsg("WARNING: Saw POS header before beginning of multi-etym sections in section %s" % (subsection_id(k)))
        dont_correct_until_etym_header = True
      else:
        check_correct = True
      expected_altform_indentation = 5 if has_etym_sections else 4
      expected_indentation = 4 if has_etym_sections else 3
    if re.search(r"==\s*Alternative forms\s*==", subsections[k]):
      expected_indentation = expected_altform_indentation
      check_correct = True
    if re.search(r"==\s*Pronunciation\s*==", subsections[k]):
      expected_indentation = expected_pron_indentation
      check_correct = True
    if check_correct and expected_indentation != indentation[k]:
      pagemsg("WARNING: Saw level %s but expected %s in section %s" % (indentation[k], expected_indentation, subsection_id(k)))
      correct_indentation(k, expected_indentation)
  if len(correct_indentation_notes) > 0:
    append_note(group_correction_notes("correct indentation of %s", correct_indentation_notes))
  return "".join(subsections), notes

def process_text_on_page(index, pagetitle, text):
  m = re.search(r"\A(.*?)(\n*)\Z", text, re.S)
  text, text_finalnl = m.groups()
  text += "\n\n"

  if args.partial_page:
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
    if re.search("^==[^\n=]*==$", text, re.M):
      pagemsg("WARNING: --partial-page specified but saw an L2 header, skipping")
      return
    check_for_bad_etym_sections(text, pagemsg)
    newtext, notes = check_for_bad_subsections(text, pagemsg, None)
    return newtext.rstrip("\n") + text_finalnl, notes

  notes = []
  sections = re.split("(^==[^\n=]*== *\n)", text, 0, re.M)
  for j in xrange(2, len(sections), 2):
    m = re.search("^==( *)(.*?)( *)==( *)\n$", sections[j - 1])
    space1, langname, space2, space3 = m.groups()
    def pagemsg(txt):
      msg("Page %s %s: %s: %s" % (index, pagetitle, langname, txt))
    if space3:
      pagemsg("WARNING: Space at end of L2 header")
    if space1 or space2:
      pagemsg("WARNING: Space surrounding section name in L2 header")
    if space1 or space2 or space3:
      if args.correct:
        sections[j - 1] = "==%s==\n" % langname
        notes.append("remove extraneous space in L2 header for language %s" % langname)
    check_for_bad_etym_sections(sections[j], pagemsg)
    newsection, this_notes = check_for_bad_subsections(sections[j], pagemsg, langname)
    sections[j] = newsection
    notes.extend(this_notes)
  return "".join(sections).rstrip("\n") + text_finalnl, notes

parser = blib.create_argparser("Find misformatted sections of various sorts; should be run on language-specific output from find_regex.py",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--correct", action="store_true", help="Correct errors as much as possible.")
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, stdin=True, edit=True)
