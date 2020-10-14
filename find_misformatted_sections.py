#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

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

def check_for_bad_etym_sections(secbody, pagemsg):
  subsections = re.split("(^===[^=\n]+===\n)", secbody, 0, re.M)

  if len(subsections) < 3:
    pagemsg("WARNING: Something wrong, didn't see three subsections")
    return

  if "==Pronunciation 1==" in secbody:
    pagemsg("WARNING: Saw Pronunciation 1")
    return

  if re.search("==Etymology [0-9]+==", secbody) and "==Etymology 1==" not in secbody:
    pagemsg("WARNING: Has ==Etymology N== but not ==Etymology 1==")
    return

  if "==Etymology 1==" not in secbody:
    return

  if subsections[1] == "===Pronunciation===\n":
    first_etym_header = 3
  else:
    first_etym_header = 1
  last_etym_header = len(subsections) - 2
  while last_etym_header > 1:
    if re.search("^===(References|See also|Related terms)===\n", subsections[last_etym_header] ):
      last_etym_header -= 2
    else:
      break
  expected_etym_no = 1
  for k in xrange(first_etym_header, last_etym_header + 2, 2):
    if subsections[k] != "===Etymology %s===\n" % expected_etym_no:
      pagemsg("WARNING: Expected ===Etymology %s=== but saw %s" % (
        expected_etym_no, subsections[k].strip()))
    expected_etym_no += 1

def check_for_bad_subsections(secbody, pagemsg):
  subsections = re.split("(^===+[^=\n]+===+\n)", secbody, 0, re.M)
  indentation = {}
  for k in xrange(2, len(subsections), 2):
    if re.search("^==", subsections[k], re.M):
      pagemsg("WARNING: Saw badly formatted section header in section %s" % k)
  for k in xrange(1, len(subsections), 2):
    m = re.match("^(=+).*?(=+)\n", subsections[k])
    indentation[k] = len(m.group(1))
    if indentation[k] != len(m.group(2)):
      pagemsg("WARNING: Mismatched indentation, %s equal signs on left but %s on right" % (indentation[k], len(m.group(2))))
  for k in xrange(3, len(subsections), 2):
    if indentation[k] - indentation[k - 2] > 1:
      pagemsg("WARNING: Increase in %s from %s to %s in indentation level: %s, %s" % (
        indentation[k] - indentation[k - 2], indentation[k - 2],
        indentation[k], subsections[k - 2].strip(), subsections[k].strip()
      ))
  has_etym_sections = "==Etymology 1==" in secbody
  for k in xrange(1, len(subsections) - 2, 2):
    if re.search("=(Conjugation|Declension|Inflection)=", subsections[k]):
      expected_indentation = 4 + (1 if has_etym_sections else 0)
      if indentation[k] != expected_indentation:
        pagemsg("WARNING: Expected %s with indentation %s but actually has %s" % (
          subsections[k].strip(), expected_indentation, indentation[k]))
      if indentation[k + 2] > indentation[k]:
        pagemsg("WARNING: Conjugation/Declension/Inflection section has nested section %s under it" % (
          subsections[k + 2].strip()))
  beginning_of_etym_sections = None
  if has_etym_sections:
    for k in xrange(1, len(subsections), 2):
      if "==Etymology 1==" in subsections[k]:
        beginning_of_etym_sections = k
        break
    if not beginning_of_etym_sections:
      pagemsg("WARNING: Something weird, ==Etymology 1== in text but can't find section with this header")
      beginning_of_etym_sections = 1
  else:
    beginning_of_etym_sections = len(subsections)
  capitalized_lemma_poses = [k.capitalize() for k in lemma_poses]
  pos_regex = "==(%s)==" % "|".join(capitalized_lemma_poses)
  for k in xrange(1, len(subsections), 2):
    if re.search("==(Alternative forms|Pronunciation)==", subsections[k]):
      expected_indentation = 3 if k < beginning_of_etym_sections else 4
      if expected_indentation != indentation[k]:
        pagemsg("WARNING: Saw %s at level %s but expected %s" % (
          subsections[k].strip(), indentation[k], expected_indentation))
    if re.search(pos_regex, subsections[k]):
      expected_indentation = 4 if has_etym_sections else 3
      if expected_indentation != indentation[k]:
        pagemsg("WARNING: Saw %s at level %s but expected %s" % (
          subsections[k].strip(), indentation[k], expected_indentation))

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  check_for_bad_etym_sections(text, pagemsg)
  check_for_bad_subsections(text, pagemsg)

parser = blib.create_argparser("Find misformatted sections of various sorts; should be run on language-specific output from find_regex.py",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, stdin=True)
