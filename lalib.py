#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def find_latin_section(text, pagemsg):
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  has_non_latin = False

  latin_j = -1
  for j in xrange(2, len(sections), 2):
    if sections[j-1] != "==Latin==\n":
      has_non_latin = True
    else:
      if latin_j >= 0:
        pagemsg("WARNING: Found two Latin sections, skipping")
        return None
      latin_j = j
  if latin_j < 0:
    pagemsg("Can't find Latin section, skipping")
    return None
  j = latin_j

  # Extract off trailing separator
  mm = re.match(r"^(.*?\n)(\n*--+\n*)$", sections[j], re.S)
  if mm:
    secbody, sectail = mm.group(1), mm.group(2)
  else:
    secbody = sections[j]
    sectail = ""

  # Split off categories at end
  mm = re.match(r"^(.*?\n)(\n*(\[\[Category:[^\]]+\]\]\n*)*)$",
      secbody, re.S)
  if mm:
    secbody, secbodytail = mm.group(1), mm.group(2)
    sectail = secbodytail + sectail

  return sections, j, secbody, sectail, has_non_latin


la_noun_decl_templates = {
  "la-decl-1st",
  "la-decl-first",
  "la-decl-first-loc",
  "la-decl-1st-1st",
  "la-decl-1st-1st-loc",
  "la-decl-1st-abus",
  "la-decl-1st-am",
  "la-decl-1st-Greek",
  "la-decl-1st-Greek-Ma",
  "la-decl-1st-Greek-Me",
  "la-decl-2nd",
  "la-decl-second",
  "la-decl-2nd-2nd",
  "la-decl-2nd-er",
  "la-decl-2nd-Greek",
  "la-decl-2nd-N-ium",
  "la-decl-2nd-ius",
  "la-decl-2nd-N",
  "la-decl-2nd-N-Greek",
  "la-decl-2nd-N-us",
  "la-decl-3rd",
  "la-decl-3rd-Greek",
  "la-decl-3rd-Greek-er",
  "la-decl-3rd-Greek-on-M",
  "la-decl-3rd-Greek-s",
  "la-decl-3rd-is",
  "la-decl-3rd-I",
  "la-decl-3rd-I-ignis",
  "la-decl-3rd-I-navis",
  "la-decl-3rd-N",
  "la-decl-3rd-N-I",
  "la-decl-3rd-N-I-pure",
  "la-decl-3rd-polis",
  "la-decl-4th",
  "la-decl-4th-argo",
  "la-decl-4th-echo",
  "la-decl-4th-loc+2nd-adj",
  "la-decl-4th-N",
  "la-decl-4th-N-ubus",
  "la-decl-4th-ubus",
  "la-decl-5th",
  "la-decl-5th-i",
  "la-decl-5th-VOW",
  "la-decl-indecl",
  "la-decl-irreg",
  "la-decl-multi",
}

la_noun_decl_suffix_to_decltype = {
  '1st': '1',
  'first': None,
  'first-loc': None,
  '1st-1st': None,
  '1st-1st-loc': None,
  '1st-abus': ('1', 'abus'),
  '1st-am': ('1', 'am'),
  '1st-Greek': ('1', 'Greek'),
  '1st-Greek-Ma': ('1', 'Greek-Ma'),
  '1st-Greek-Me': ('1', 'Greek-Me'),
  '2nd': '2',
  'second': None,
  '2nd-2nd': None,
  '2nd-er': ('2', 'er'),
  '2nd-Greek': ('2', 'Greek'),
  '2nd-N-ium': ('2', 'N-ium'),
  '2nd-ius': ('2', 'ius'),
  '2nd-N': ('2', 'N'),
  '2nd-N-Greek': ('2', 'Greek-N'),
  '2nd-N-us': ('2', 'N-us'),
  '3rd': '3',
  '3rd-Greek': ('3', 'Greek'),
  '3rd-Greek-er': ('3', 'Greek-er'),
  '3rd-Greek-on-M': ('3', 'Greek-on'),
  '3rd-Greek-s': ('3', 'Greek-s'),
  '3rd-is': ('3', 'is'),
  '3rd-I': ('3', 'I'),
  '3rd-I-ignis': ('3', 'ignis'),
  '3rd-I-navis': ('3', 'navis'),
  '3rd-N': ('3', 'N'),
  '3rd-N-I': ('3', 'N-I'),
  '3rd-N-I-pure': ('3', 'N-I-pure'),
  '3rd-polis': ('3', 'polis', 'sg'),
  '4th': '4',
  '4th-argo': None, 
  '4th-echo': None,
  '4th-loc+2nd-adj': None,
  '4th-N': ('4', 'N'),
  '4th-N-ubus': ('4', 'N-ubus'),
  '4th-ubus': ('4', 'ubus'),
  '5th': '5',
  '5th-i': ('5', 'i'),
  '5th-VOW': ('5', 'vow'),
  'indecl': 'indecl',
  'irreg': 'irreg', # only if noun=something
  'multi': None,
}

la_adj_decl_templates = {
  "la-decl-1&2",
  "la-adecl-2nd",
  "la-decl-3rd-1E",
  "la-decl-3rd-2E",
  "la-decl-3rd-3E",
  "la-decl-3rd-comp",
  "la-decl-3rd-part",
  "la-decl-irreg",
  "la-decl-multi",
}

la_verb_conj_templates = {
  "la-conj-1st",
  "la-conj-2nd",
  "la-conj-3rd",
  "la-conj-3rd-IO",
  "la-conj-4th",
  "la-conj-irreg",
}

la_infl_templates = (
  la_noun_decl_templates |
  la_adj_decl_templates |
  la_verb_conj_templates
)

la_adj_headword_templates = {
  "la-adj-1&2",
  "la-adj-3rd-1E",
  "la-adj-3rd-2E",
  "la-adj-3rd-3E",
  "la-adj-comparative",
  "la-adj-superlative",
}

la_suffix_headword_templates = {
  "la-suffix",
  "la-suffix-1&2",
  "la-suffix-3rd-2E",
  "la-suffix-adv",
  "la-suffix-noun",
}

la_participle_headword_templates = {
  "la-present participle",
  "la-future participle",
  "la-perfect participle",
  "la-gerundive",
}

la_nonlemma_headword_templates = {
  "la-adj-form",
  "la-comp-form",
  "la-gerund-form",
  "la-noun-form",
  "la-proper noun-form",
  "la-num-form",
  "la-part-form",
  "la-pronoun-form",
  "la-suffix-form",
  "la-verb-form",
}

la_misc_headword_templates = {
  "la-adv",
  "la-diacritical mark",
  "la-gerund",
  "la-interj",
  "la-phrase",
  "la-letter",
  "la-location",
  "la-noun",
  "la-proper noun",
  "la-num-1&2",
  "la-num-card",
  "la-punctuation mark",
  "la-verb",
}

la_lemma_headword_templates = (
  la_adj_headword_templates |
  la_suffix_headword_templates |
  la_participle_headword_templates |
  la_misc_headword_templates
)

la_headword_templates = la_lemma_headword_templates | la_nonlemma_headword_templates

la_infl_of_templates = {
  "inflection of",
  "noun form of",
  "verb form of",
  "adj form of",
  "participle of",
}

third_decl_stem_patterns = [
  (u"tūdō", u"tūdin"),
  ("is", ""),
  (u"āns", "ant"),
  (u"ēns", "ent"),
  (u"ōns", "ont"),
  ("ceps", "cipit"),
  ("us", "or"),
  ("ex", "ic"),
  ("ma", "mat"),
  ("e", ""),
  ("men", "min"),
  ("er", "r"),
  ("or", u"ōr"),
  (u"ō", u"ōn"),
  ("s", "t"),
  ("x", "c"),
]

def infer_3rd_decl_stem(nomsg):
  # According to algorithm in [[Module:la-utilities]]
  for nomsg_ending, stem_ending in third_decl_stem_patterns:
    if nomsg.endswith(nomsg_ending):
      return nomsg[:-len(nomsg_ending)] + stem_ending
  return nomsg

def generate_adj_forms(template, errandpagemsg, expand_text):

  def generate_adj_forms_prefix(m):
    decl_suffix_to_decltype = {
      'decl-1&2': '1&2',
      'decl-3rd-1E': '3-1',
      'decl-3rd-2E': '3-2',
      'decl-3rd-3E': '3-3',
      'decl-3rd-comp': '3-C',
      'decl-3rd-part': '3-P',
      'adecl-2nd': '2-2',
      'decl-irreg': 'irreg',
    }
    if m.group(1) in decl_suffix_to_decltype:
      return "{{la-generate-adj-forms|decltype=%s|" % (
        decl_suffix_to_decltype[m.group(1)]
      )
    return m.group(0)

  generate_template = re.sub(r"^\{\{la-(.*?)\|", generate_adj_forms_prefix,
      template)
  if not generate_template.startswith("{{la-generate-adj-forms|"):
    errandpagemsg("Template %s not a recognized declension template" % template)
    return None
  result = expand_text(generate_template)
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  return blib.split_generate_args(result)

def generate_noun_forms(template, errandpagemsg, expand_text):

  def generate_noun_forms_prefix(m):
    if m.group(1) in la_noun_decl_suffix_to_decltype:
      return "{{la-generate-adj-forms|decltype=%s|" % (
        decl_suffix_to_decltype[m.group(1)]
      )
    return m.group(0)

  generate_template = re.sub(r"^\{\{la-(.*?)\|", generate_adj_forms_prefix,
      template)
  if not generate_template.startswith("{{la-generate-adj-forms|"):
    errandpagemsg("Template %s not a recognized declension template" % template)
    return None
  result = expand_text(generate_template)
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  return blib.split_generate_args(result)

def generate_verb_forms(template, errandpagemsg, expand_text):
  if template.startswith("{{la-conj-3rd-IO|"):
    generate_template = re.sub(r"^\{\{la-conj-3rd-IO\|", "{{la-generate-verb-forms|conjtype=3rd-io|", template)
  else:
    generate_template = re.sub(r"^\{\{la-conj-(.*?)\|", r"{{la-generate-verb-forms|conjtype=\1|", template)
  if not generate_template.startswith("{{la-generate-verb-forms|"):
    errandpagemsg("Template %s not a recognized conjugation template" % template)
    return None
  result = expand_text(generate_template)
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  return blib.split_generate_args(result)

demacron_mapper = {
  u'ā': 'a',
  u'ē': 'e',
  u'ī': 'i',
  u'ō': 'o',
  u'ū': 'u',
  u'ȳ': 'y',
  u'Ā': 'A',
  u'Ē': 'E',
  u'Ī': 'I',
  u'Ō': 'O',
  u'Ū': 'U',
  u'Ȳ': 'Y',
  u'ă': 'a',
  u'ĕ': 'e',
  u'ĭ': 'i',
  u'ŏ': 'o',
  u'ŭ': 'u',
  # no composed breve-y
  u'Ă': 'A',
  u'Ĕ': 'E',
  u'Ĭ': 'I',
  u'Ŏ': 'O',
  u'Ŭ': 'U',
  # combining breve
  u'\u0306': '',
  u'ë': 'e',
  u'Ë': 'E',
}

def remove_macrons(text):
  return re.sub(u'([āēīōūȳĀĒĪŌŪȲăĕĭŏŭĂĔĬŎŬ\u0306ëË])', lambda m: demacron_mapper[m.group(1)], text)

