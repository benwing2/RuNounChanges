# !/usr/bin/env python
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

def extract_base(lemma, ending):
  if "(" in ending:
    return re.search(ending, lemma)
  else:
    return re.search("^(.*)" + ending + "$", lemma)

def stem_matches_any(stem1, stem2, endings_and_subtypes):
  stem2 = stem2 or infer_3rd_decl_stem(stem1)
  for ending, subtypes in endings_and_subtypes:
    if type(ending) is tuple:
      stem1_ending, stem2_ending = ending
      m = extract_base(stem1, stem1_ending)
      if m and m.group(1) + stem2_ending == stem2:
        return subtypes
    else:
      m = extract_base(stem1, ending)
      if m:
        return subtypes
  return False

def la_noun_2nd_ius_subtype(stem1, stem2, num):
  if re.search(u"^[A-ZĀĒĪŌŪȲĂĔĬŎŬ]", stem1) and num != "pl":
    return ('-voci',)
  else:
    return ()

def la_noun_2nd_ius_voci_subtype(stem1, stem2, num):
  if not re.search(u"^[A-ZĀĒĪŌŪȲĂĔĬŎŬ]", stem1):
    return ('voci',)
  else:
    return ()

def la_noun_3rd_subtype(stem1, stem2, num):
  return stem_matches_any(stem1, stem2, [
    ((u"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)polis$", "pol"), ('-polis', '-I')),
    (u"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)polis$", ('-polis',)),
    (("is", ""), ('-I',)),
    ((u"^([a-zāēīōūȳăĕĭŏŭ].*)ēs$", ""), ('-I',)),
    (("us", "or"), ('-N',)),
    (("us", "er"), ('-N',)),
    (("ma", "mat"), ('-N',)),
    (("men", "min"), ('-N',)),
    (("e", ""), ('-N',)),
    (("al", u"āl"), ('-N',)),
    (("ar", u"ār"), ('-N',)),
    ("", ()),
  ])

def la_noun_3rd_Greek_subtype(stem1, stem2, num):
  if stem1.endswith(u"ēr"):
    return ('Greek', '-er')
  if stem1.endswith(u"ōn"):
    return ('Greek', '-on')
  if stem1.endswith("s"):
    return ('Greek', '-s')
  return ('Greek',)

def la_noun_3rd_I_subtype(stem1, stem2, num):
  return stem_matches_any(stem1, stem2, [
    ((u"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)polis$", "pol"), ('-polis',)),
    (u"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)polis$", ('-polis', 'I')),
    (("is", ""), ()),
    ((u"^([a-zāēīōūȳăĕĭŏŭ].*)ēs$", ""), ()),
    (("us", "or"), ('-N', 'I')),
    (("us", "er"), ('-N', 'I')),
    (("ma", "mat"), ('-N', 'I')),
    (("men", "min"), ('-N', 'I')),
    (("e", ""), ('-N', 'I')),
    (("al", u"āl"), ('-N', 'I')),
    (("ar", u"ār"), ('-N', 'I')),
    ("", ('I',)),
  ])

def la_noun_3rd_N_subtype(stem1, stem2, num):
  return stem_matches_any(stem1, stem2, [
    (("us", "or"), ()),
    (("us", "er"), ()),
    (("ma", "mat"), ()),
    (("men", "min"), ()),
    ((u"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)e$", ""), ()),
    (("e", ""), ('N', '-pure')),
    (("al", u"āl"), ('N', '-pure')),
    (("ar", u"ār"), ('N', '-pure')),
    ("", ('N',)),
  ])

def la_noun_3rd_N_I_subtype(stem1, stem2, num):
  return stem_matches_any(stem1, stem2, [
    ((u"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)e$", ""), ('N', 'I')),
    (("e", ""), ('N', 'I', '-pure')),
    (("al", u"āl"), ('N', 'I', '-pure')),
    (("ar", u"ār"), ('N', 'I', '-pure')),
    ("", ('N', 'I')),
  ])

def la_noun_3rd_N_I_pure_subtype(stem1, stem2, num):
  return stem_matches_any(stem1, stem2, [
    ((u"^([A-ZĀĒĪŌŪȲĂĔĬŎŬ].*)e$", ""), ('N', 'I', 'pure')),
    (("e", ""), ()),
    (("al", u"āl"), ()),
    (("ar", u"ār"), ()),
    ("", ('N', 'I', 'pure')),
  ])

def la_noun_3rd_polis_subtype(stem1, stem2, num):
  if not re.search(u"^[A-ZĀĒĪŌŪȲĂĔĬŎŬ]", stem1):
    return ('polis',)
  else:
    return ()

# The key is the decl suffix found in the template name, e.g.
# {{la-decl-1st-abus}} maps to key '1st-abus'. The value is a three-entry
# list of [DECLSPEC, STEM_SUFFIX, TO_AUTO] where:
#
# * DECLSPEC is either a single string (the declension type, e.g. '2', '3'),
#   or a tuple of (DECLTYPE, SUBTYPE), or a tuple of (DECLTYPE, SUBTYPE, NUM),
#   where DECLTYPE is the declension type as above (e.g. '2', '3'); optional
#   SUBTYPE specifies a value for the decl_type= invocation or parent argument
#   (e.g. 'Greek', 'N-ium')gument; and optional NUM specifies a value for the
#   num= invocation or parent argument.
# * STEM_SUFFIX is the suffix to add to the stem specified in 1= in order to
#   get the lemma.
# * PL_SUFFIX is the suffix to add to the stem specified in 1= in order to
#   get the plural lemma; but should be None if the new, autodetecting mechanism
#   can't detect such plurals.
# * TO_AUTO specifies any subtypes that need to be provided when using the
#   new, autodetecting mechanism, and is either a tuple of subtypes, possibly
#   empty, or a function of one argument (the old-style template) that returns
#   a tuple of subtypes. Any of the subtypes can be "negative", i.e. a subtype
#   prefixed by a hyphen, which cancels out that subtype if it was
#   autodetected. In such a case, a warning will be issued in the code to
#   convert from old-style to new-style declension templates, because this
#   may well indicate a mistake in the old-style template.

la_noun_decl_suffix_to_decltype = {
  '1st': ['1', 'a', 'ae', ()],
  '1st-abus': [('1', 'abus'), 'a', 'ae', ('abus',)],
  '1st-am': [('1', 'am'), u'ām', None, ()],
  '1st-Greek': [('1', 'Greek'), u'ē', None, ()],
  '1st-Greek-Ma': [('1', 'Greek-Ma'), u'ās', None, ()],
  '1st-Greek-Me': [('1', 'Greek-Me'), u'ēs', None, ()],
  '2nd': ['2', 'us', u'ī',
    lambda stem1, stem2, num: ('-ius',) if stem1.endswith('i') else ()],
  '2nd-er': [('2', 'er'), '', None, ()],
  '2nd-Greek': [('2', 'Greek'), 'os', None, ()],
  '2nd-N-ium': [('2', 'N-ium'), 'ium', 'ia', ()],
  '2nd-ius': [('2', 'ius'), 'ius', u'iī', la_noun_2nd_ius_subtype],
  '2nd-ius-voci': [('2', 'ius-voci'), 'ius', u'iī', la_noun_2nd_ius_voci_subtype],
  '2nd-N': [('2', 'N'), 'um', 'a',
    lambda stem1, stem2, num: ('-ium',) if stem1.endswith('i') else ()],
  '2nd-N-Greek': [('2', 'Greek-N'), 'on', None, ()],
  '2nd-N-us': [('2', 'N-us'), 'us', u'ī', ('N',)],
  '3rd': ['3', '', None, la_noun_3rd_subtype],
  '3rd-Greek': [('3', 'Greek'), '', None, la_noun_3rd_Greek_subtype],
  '3rd-Greek-er': [('3', 'Greek-er'), u'ēr', None, ('Greek',)],
  '3rd-Greek-on-M': [('3', 'Greek-on'), u'ōn', None, ('Greek',)],
  '3rd-Greek-s': [('3', 'Greek-s'), 's', None, ('Greek',)],
  '3rd-is': [('3', 'is'), '', None, ('is',)],
  '3rd-I': [('3', 'I'), '', None, la_noun_3rd_I_subtype],
  '3rd-I-ignis': [('3', 'ignis'), '', None, ('ignis',)],
  '3rd-I-navis': [('3', 'navis'), '', None, ('navis',)],
  '3rd-N': [('3', 'N'), '', None, la_noun_3rd_N_subtype],
  '3rd-N-I': [('3', 'N-I'), '', None, la_noun_3rd_N_I_subtype],
  '3rd-N-I-pure': [('3', 'N-I-pure'), '', None, la_noun_3rd_N_I_pure_subtype],
  '3rd-polis': [('3', 'polis', 'sg'), 'polis', None, la_noun_3rd_polis_subtype],
  '4th': ['4', 'us', u'ūs', ()],
  '4th-argo': [('4', 'argo'), u'ō', None, ('argo',)],
  '4th-echo': [('4', 'echo'), u'ō', None, ('echo',)],
  '4th-N': [('4', 'N'), u'ū', 'ua', ()],
  '4th-N-ubus': [('4', 'N-ubus'), u'ū', 'ua', ('ubus',)],
  '4th-ubus': [('4', 'ubus'), 'us', u'ū', ('ubus', )],
  '5th': ['5', u'ēs', None,
    lambda stem1, stem2, num: ('-i',) if stem1.endswith('i') else ()],
  '5th-i': [('5', 'i'), u'iēs', None, ()],
  '5th-VOW': [('5', 'vow'), u'ēs', None,
    lambda stem1, stem2, num: ('-i',) if stem1.endswith('i') else ()],
  'indecl': ['indecl', '', None, ()],
  'irreg': ['irreg', '', None, ()], # only if noun=something
  'multi': None,
}

noun_decl_and_subtype_to_props = {}
for key, val in la_noun_decl_suffix_to_decltype.iteritems():
  if val is None:
    continue
  declspec, stem_suffix, pl_suffix, to_auto = val
  if type(declspec) is not tuple:
    declspec = (declspec,)
  decl = declspec[0]
  if len(declspec) == 1:
    subtypes = ()
    num = ""
  else:
    subtypes = tuple(declspec[1].split("-"))
    if len(declspec) == 2:
      num = ""
    else:
      num = declspec[2]
  noun_decl_and_subtype_to_props[(decl, subtypes)] = [num, stem_suffix, pl_suffix, to_auto]

def la_adj_1_and_2_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if stem2:
    pagemsg("WARNING: stem2=%s should not be present with 1&2 adjectives" %
        stem2)
    stem2 = ""
  set_stem1 = False
  if stem1.endswith("(e)r"):
    if num == "pl":
      stem2 = stem1[:-4] + ("rae" if g == "F" else u"rī")
    elif g in ["F", "N"]:
      stem2 = stem1[:-4] + ("ra" if g == "F" else u"rum")
    else:
      stem2 = stem1[:-4] + "r"
      stem1 = stem1[:-4] + "er"
    set_stem1 = True
  elif stem1.endswith("er") or stem1.endswith("ur"):
    macronless_stem1 = remove_macrons(stem1)
    if macronless_stem1 != pagetitle and macronless_stem1 + "us" != pagetitle:
      pagemsg("WARNING: Potential 1&2 adjective ending in -er or -ur, but pagetitle=%s not same" %
          pagetitle)
    if macronless_stem1 == pagetitle:
      if num == "pl":
        stem1 += ("ae" if g == "F" else u"ī")
      elif g in ["F", "N"]:
        stem1 += ("a" if g == "F" else "um")
      set_stem1 = True
  if not set_stem1:
    if "greekA" in types or "greekE" in types:
      stem1 += ("on" if g == "N" else "os")
      types = [x for x in types if x != "greekA"]
      if num == "pl":
        types = types + ["pl"]
    elif "ic" in types:
      stem1 += "ic"
      types = [x for x in types if x != "ic"]
    elif num == "pl":
      stem1 += ("ae" if g == "F" else u"ī")
    else:
      stem1 += ("a" if g == "F" else "um" if g == "N" else "us")
  types = ["lig" if x == "ea" else x for x in types]
  return stem1, stem2, "", types

def la_adj_1_1_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if stem2:
    pagemsg("WARNING: stem2=%s should not be present with 1-1 adjectives" %
        stem2)
    stem2 = ""
  stem1 += "ae" if num == "pl" else "a"
  return stem1, stem2, decl, types

def la_adj_2_2_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if stem2:
    pagemsg("WARNING: stem2=%s should not be present with 2-2 adjectives" %
        stem2)
    stem2 = ""
  if num == "pl":
    stem1 += "a" if g == "N" else u"ī"
  else:
    stem1 += "um" if g == "N" else u"us"
  return stem1, stem2, decl, types

def la_adj_3rd_1E_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if "par" in types:
    types = ["-I" if x == "par" else x for x in types]
  if num == "pl":
    types = types + ["pl"]
  if stem2 == infer_3rd_decl_stem(stem1):
    stem2 = ""
  if re.search("(is|[ij]or|e)$", stem1):
    pagemsg("WARNING: Possible wrongly tagged adj, decl=3-1, stem1=%s, stem2=%s" % (
      stem1, stem2))
    decl = "3-1"
  elif stem1.endswith("er"):
    # Just 3 is detected as 3-3
    decl = "3-1"
  elif re.search(u"(us|a|um|ī|ae|ur|os|ē|on)$", stem1) or stem1 == "hic":
    decl = "3"
  else:
    decl = ""
  return stem1, stem2, decl, types

def la_adj_3rd_2E_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if num == "pl":
    types = types + ["pl"]
  if stem2:
    pagemsg("WARNING: stem2=%s present with decl=3-2" % stem2)
    stem2 = ""
  stem1 += ("e" if g == "N" else "is")
  decl = ""
  return stem1, stem2, decl, types

def la_adj_3rd_3E_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if num == "pl":
    types = types + ["pl"]
  if stem2 == infer_3rd_decl_stem(stem1):
    stem2 = ""
  if not stem1.endswith("er"):
    pagemsg("WARNING: Possible wrongly tagged adj, decl=3-3, stem1=%s, stem2=%s" % (
      stem1, stem2))
    decl = "3-2"
  else:
    decl = "3" # need to indicate 3 to distinguish from 1&2 adjs in -er
  if g in ["F", "N"]:
    stem1 = stem2 + ("is" if g == "F" else "e")
    stem2 = ""
  return stem1, stem2, decl, types

def la_adj_3rd_comp_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if num == "pl":
    types = types + ["pl"]
  if stem2:
    if stem2 == "j":
      stem1 += "jor"
      stem2 = ""
    elif stem2 == "n" and stem1 == "mi":
      stem1 = "minor"
      stem2 = ""
    else:
      pagemsg("WARNING: strange stem2=%s present with decl=3-C" % stem2)
  else:
    stem1 += "ior"
  decl = ""
  return stem1, stem2, decl, types

def la_adj_3rd_part_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if num == "pl":
    types = types + ["pl"]
  if not re.search(u"[āē]ns$", stem1):
    pagemsg("WARNING: strange stem1=%s present with decl=3-P" % stem1)
  if stem2 and not stem2.endswith("eunt"):
    pagemsg("WARNING: strange stem2=%s present with decl=3-P" % stem2)
  return stem1, stem2, decl, types

def la_adj_irreg_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if num == "pl":
    types = types + ["pl"]
  return stem1, stem2, decl, types

la_adj_decl_suffix_to_decltype = {
  'decl-1&2': ['1&2', la_adj_1_and_2_subtype],
  'adecl-1st': ['1-1', la_adj_1_1_subtype],
  'adecl-2nd': ['2-2', la_adj_2_2_subtype],
  'decl-3rd-1E': ['3-1', la_adj_3rd_1E_subtype],
  'decl-3rd-2E': ['3-2', la_adj_3rd_2E_subtype],
  'decl-3rd-3E': ['3-3', la_adj_3rd_3E_subtype],
  'decl-3rd-comp': ['3-C', la_adj_3rd_comp_subtype],
  'decl-3rd-part': ['3-P', la_adj_3rd_part_subtype],
  'decl-irreg': ['irreg', la_adj_irreg_subtype],
}

adj_decl_and_subtype_to_props = {}
for key, val in la_adj_decl_suffix_to_decltype.iteritems():
  decl, compute_props = val
  adj_decl_and_subtype_to_props[decl] = [key, compute_props]

la_noun_decl_templates = set(
  'la-decl-%s' % k for k in la_noun_decl_suffix_to_decltype
)

la_adj_decl_templates = {
  "la-decl-1&2",
  "la-adecl-1st",
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
  la_verb_conj_templates |
  {"la-decl-gerund"}
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
  "la-suffix-verb",
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
  "la-prep",
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


la_lemma_poses = {
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

la_nonlemma_poses = {
  "adjective form",
  "determiner form",
  "gerund form",
  "noun form",
  "numeral form",
  "participle form",
  "pronoun form",
  "proper noun form",
  "verb form",
}

la_poses = la_lemma_poses | la_nonlemma_poses

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
  (u"ēs", ""),
  (u"āns", "ant"),
  (u"ēns", "ent"),
  (u"ōns", "ont"),
  ("ceps", "cipit"),
  ("us", "or"),
  ("ex", "ic"),
  ("ma", "mat"),
  ("e", ""),
  ("al", u"āl"),
  ("ar", u"ār"),
  ("men", "min"),
  ("er", "r"),
  ("or", u"ōr"),
  (u"ō", u"ōn"),
  ("ps", "p"),
  ("bs", "b"),
  ("s", "t"),
  ("x", "c"),
]

def infer_3rd_decl_stem(nomsg):
  # According to algorithm in [[Module:la-utilities]]
  for nomsg_ending, stem_ending in third_decl_stem_patterns:
    if nomsg.endswith(nomsg_ending):
      return nomsg[:-len(nomsg_ending)] + stem_ending
  return nomsg

adv_stem_patterns = [
  "iter",
  ("nter", "nt"),
  "ter",
  "er",
  u"iē",
  u"ē",
  "im",
  u"ō",
  "e",
]

def infer_adv_stem(adv):
  # According to algorithm in [[Module:la-headword]], with -e added
  for pattern in adv_stem_patterns:
    if type(pattern) is tuple:
      suffix, newsuff = pattern
    else:
      suffix = pattern
      newsuff = ""
    if adv.endswith(suffix):
      return adv[:-len(suffix)] + newsuff
  return adv

def generate_adj_forms(template, errandpagemsg, expand_text, return_raw=False):

  def generate_adj_forms_prefix(m):
    decl_suffix_to_decltype = {
      'decl-1&2': '1&2',
      'decl-3rd-1E': '3-1',
      'decl-3rd-2E': '3-2',
      'decl-3rd-3E': '3-3',
      'decl-3rd-comp': '3-C',
      'decl-3rd-part': '3-P',
      'adecl-1st': '1-1',
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
    errandpagemsg("Template %s not a recognized adjective declension template" % template)
    return None
  result = expand_text(generate_template)
  if return_raw:
    return None if result is False else result
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  args = blib.split_generate_args(result)
  # Add missing feminine forms if needed
  augmented_args = {}
  for key, form in args.iteritems():
    augmented_args[key] = form
    if key.endswith("_m"):
      equiv_fem = key[:-2] + "_f"
      if equiv_fem not in args:
        augmented_args[equiv_fem] = form
  return augmented_args

def generate_noun_forms(template, errandpagemsg, expand_text, return_raw=False):

  def generate_noun_forms_prefix(m):
    if m.group(1) in la_noun_decl_suffix_to_decltype:
      declspec, stem_suffix, pl_suffix, to_auto = la_noun_decl_suffix_to_decltype[m.group(1)]
      if type(declspec) is not tuple:
        declspec = (declspec,)
      decl = declspec[0]
      if len(declspec) == 1:
        decltype = ""
        num = ""
      else:
        decltype = "|decl_type=%s" % declspec[1]
        if len(declspec) == 2:
          num = ""
        else:
          num = "|num=%s" % declspec[2]
      return "{{la-generate-noun-forms|decl=%s%s%s|" % (
        decl, decltype, num
      )
    return m.group(0)

  generate_template = re.sub(r"^\{\{la-decl-(.*?)\|", generate_noun_forms_prefix,
      template)
  if not generate_template.startswith("{{la-generate-noun-forms|"):
    errandpagemsg("Template %s not a recognized noun declension template" % template)
    return None
  result = expand_text(generate_template)
  if return_raw:
    return None if result is False else result
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  return blib.split_generate_args(result)

def generate_verb_forms(template, errandpagemsg, expand_text, return_raw=False):
  if template.startswith("{{la-conj-3rd-IO|"):
    generate_template = re.sub(r"^\{\{la-conj-3rd-IO\|", "{{la-generate-verb-forms|conjtype=3rd-io|", template)
  else:
    generate_template = re.sub(r"^\{\{la-conj-(.*?)\|", r"{{la-generate-verb-forms|conjtype=\1|", template)
  if not generate_template.startswith("{{la-generate-verb-forms|"):
    errandpagemsg("Template %s not a recognized conjugation template" % template)
    return None
  result = expand_text(generate_template)
  if return_raw:
    return None if result is False else result
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  return blib.split_generate_args(result)

def generate_infl_forms(pos, template, errandpagemsg, expand_text, return_raw=False):
  if pos == 'noun':
    return generate_noun_forms(template, errandpagemsg, expand_text, return_raw)
  elif pos == 'verb':
    return generate_verb_forms(template, errandpagemsg, expand_text, return_raw)
  elif pos in ['adj', 'part']:
    return generate_adj_forms(template, errandpagemsg, expand_text, return_raw)
  else:
    errandpagemsg("WARNING: Bad pos=%s, expected noun/verb/adj")
    return None

MACRON = u"\u0304" # macron =  ̄
BREVE = u"\u0306" # breve =  ̆
DOUBLE_INV_BREVE = u"\u0361" # double inverted breve
DIAER = u"\u0308" # diaeresis =  ̈

combining_accents = [MACRON, BREVE, DOUBLE_INV_BREVE, DIAER]

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
  MACRON: '',
  BREVE: '',
  DOUBLE_INV_BREVE: '',
  u'ä': 'a',
  u'Ä': 'A',
  u'ë': 'e',
  u'Ë': 'E',
  u'ï': 'i',
  u'Ï': 'I',
  u'ö': 'o',
  u'Ö': 'O',
  u'ü': 'u',
  u'Ü': 'U',
  u'ÿ': 'y',
  u'Ÿ': 'Y',
  DIAER: '',
}

macron_breve_etc_no_diaeresis = u'āēīōūȳĀĒĪŌŪȲăĕĭŏŭĂĔĬŎŬ' + MACRON + BREVE + DOUBLE_INV_BREVE
macron_breve_etc = macron_breve_etc_no_diaeresis + u'äÄëËïÏöÖüÜÿŸ' + DIAER

def remove_macrons(text, preserve_diaeresis=False):
  if preserve_diaeresis:
    return re.sub(u'([' + macron_breve_etc_no_diaeresis + '])', lambda m: demacron_mapper[m.group(1)], text)
  else:
    return re.sub(u'([' + macron_breve_etc + '])', lambda m: demacron_mapper[m.group(1)], text)

parts_to_tags = {
  # parts for verbs
  '1s': ['1', 's'],
  '2s': ['2', 's'],
  '3s': ['3', 's'],
  '1p': ['1', 'p'],
  '2p': ['2', 'p'],
  '3p': ['3', 'p'],
  'actv': ['act'],
  'pasv': ['pass'],
  'pres': ['pres'],
  'impf': ['impf'],
  'futr': ['fut'],
  'perf': ['perf'],
  'plup': ['plup'],
  'futp': ['fut', 'perf'],
  'indc': ['ind'],
  'subj': ['sub'],
  'impr': ['imp'],
  'inf': ['inf'],
  'ptc': ['part'],
  'ger': ['ger'],
  'sup': ['sup'],
  'nom': ['nom'],
  'gen': ['gen'],
  'dat': ['dat'],
  'acc': ['acc'],
  'abl': ['abl'],
  # additional parts for adjectives
  'voc': ['voc'],
  'sg': ['s'],
  'pl': ['p'],
  'm': ['m'],
  'f': ['f'],
  'n': ['n'],
  # additional parts for nouns
  'loc': ['loc'],
}

tags_to_canonical = {
  'first-person': '1',
  'second-person': '2',
  'third-person': '3',
  'sg': 's',
  'singular': 's',
  'pl': 'p',
  'plural': 'p',
  'actv': 'act',
  'active': 'act',
  'pasv': 'pass',
  'passive': 'pass',
  'imperf': 'impf',
  'imperfect': 'impf',
  'futr': 'fut',
  'future': 'fut',
  'perfect': 'perf',
  'pluperf': 'plup',
  'pluperfect': 'plup',
  'indc': 'ind',
  'indic': 'ind',
  'indicative': 'ind',
  'subj': 'sub',
  'subjunctive': 'sub',
  'impr': 'imp',
  'impv': 'imp',
  'imperative': 'imp',
  'infinitive': 'inf',
  'ptcp': 'part',
  'participle': 'part',
  'gerund': 'ger',
  'supine': 'sup',
  'nominative': 'nom',
  'genitive': 'gen',
  'dative': 'dat',
  'accusative': 'acc',
  'ablative': 'abl',
  'vocative': 'voc',
  'masculine': 'm',
  'feminine': 'f',
  'neuter': 'n',
}

semicolon_tags = [';', ';<!--\n-->']

# Split a possibly multipart tag set into individual tag sets
# without any multipart tags. Can handle multiple multipart tags
# in a single tag set, e.g. 'dat//abl|m//f//n|p' will split into
# six tag sets.
def split_multipart_tag_set(tag_set):
  split_tag_sets = [tag_set]
  while True:
    new_tag_sets = []
    found_multipart = False
    for ts in split_tag_sets:
      for i, tag in enumerate(ts):
        if "//" in tag:
          for split_tag in tag.split("//"):
            new_tag_sets.append(ts[0:i] + [split_tag] + ts[i+1:])
          found_multipart = True
          break
      else:
        # no break
        new_tag_sets.append(ts)
    split_tag_sets = new_tag_sets
    if not found_multipart:
      break
  return split_tag_sets

def split_tags_into_tag_sets(tags):
  tag_set_group = []
  cur_tag_set = []
  for tag in tags:
    if tag in semicolon_tags:
      if cur_tag_set:
        tag_set_group.append(cur_tag_set)
      cur_tag_set = []
    else:
      cur_tag_set.append(tag)
  if cur_tag_set:
    tag_set_group.append(cur_tag_set)
  return tag_set_group

def combine_tag_set_group(group):
  result = []
  for tag_set in group:
    if result:
      result.append(";")
    result.extend(tag_set)
  return result

def canonicalize_tag_set(tag_set):
  new_tag_set = []
  for tag in tag_set:
    new_tag_set.append(tags_to_canonical.get(tag, tag))
  return new_tag_set

def form_key_to_tag_set(key):
  parts = key.split("_")
  tags = []
  for part in parts:
    tags.extend(parts_to_tags[part])
  return tags

cases = [ "nom", "gen", "dat", "acc", "abl", "voc", "loc" ]

la_noun_decl_overrides = [ "%s_%s" % (case, num)
  for num in ["sg", "pl"] for case in cases]

la_adj_decl_overrides = [ "%s_%s_%s" % (case, num, g)
  for g in ["m", "f", "n"]
  for num in ["sg", "pl"]
  for case in cases
]

la_verb_finite_overrides = [ "%s%s_%s_%s" % (pernum, tense, voice, mood)
  for pernum in ["", "1s_", "2s_", "3s_", "1p_", "2p_", "3p_"]
  for tense in ["pres", "impf", "futr", "perf", "plup", "futp"]
  for voice in ["actv", "pasv"]
  for mood in ["indc", "subj", "impr"]
  if not (
    mood == "subj" and tense in ["futr", "futp"] or
    mood == "impr" and tense in ["impf", "perf", "plup", "futp"]
  )
]

la_verb_inf_ptc_overrides = [ "%s_%s_%s" % (tense, voice, form)
  for tense in ["pres", "perf", "futr"]
  for voice in ["actv", "pasv"]
  for form in ["inf", "ptc"]
]

la_verb_ger_sup_overrides = [
  "ger_nom", "ger_gen", "ger_dat", "ger_acc",
  "sup_acc", "sup_abl"
]

la_verb_overrides = (
  la_verb_finite_overrides +
  la_verb_inf_ptc_overrides +
  la_verb_ger_sup_overrides
)

def la_infl_template_pos(t):
  tn = tname(t)
  if tn in la_verb_conj_templates:
    return "verb"
  elif tn == "la-decl-irreg":
    return "noun" if getparam(t, "noun") else "adj"
  elif tn == "la-decl-multi":
    # FIXME, hard to determine properly
    return "noun"
  elif tn in la_noun_decl_templates:
    return "noun"
  elif tn in la_adj_decl_templates:
    return "adj"
  elif tn == "la-decl-gerund":
    return "noun"
  elif tn == "la-decl-ppron":
    return "pron"
  else:
    return None

def la_template_is_head(t):
  tn = tname(t)
  if tn in la_headword_templates:
    return True
  if tn == "head" and getparam(t, "1") == "la":
    return True
  return False

def la_get_headword_from_template(t, pagename, pagemsg):
  tn = tname(t)
  if tn in la_adj_headword_templates or tn in ["la-noun", "la-suffix"]:
    retval = getparam(t, "1")
  elif tn == "la-present participle":
    stem = getparam(t, "1")
    ending = getparam(t, "2")
    if ending == "ans":
      retval = stem + u"āns"
    elif ending == "ens":
      retval = stem + u"ēns"
    elif ending == "iens":
      retval = stem + u"iēns"
    else:
      pagemsg("WARNING: Unrecognized ending for la-present participle: %s" % ending)
      retval = stem + ending
  elif tn in ["la-future participle", "la-perfect participle", "la-gerundive"]:
    retval = getparam(t, "2") or getparam(t, "1")
    if retval:
      retval = retval + "us"
  elif tn == "la-suffix-3rd-2E":
    retval = getparam(t, "1")
    if retval:
      retval = "-" + retval + "is"
  elif tn == "la-suffix-1&2":
    retval = getparam(t, "1")
    if retval:
      retval = "-" + retval + "us"
  elif tn in la_suffix_headword_templates:
    retval = getparam(t, "1")
    if retval:
      retval = "-" + retval
  elif tn == "la-suffix-form":
    retval = getparam(t, "2") or getparam(t, "1")
    if retval:
      retval = "-" + retval
  elif tn == "head":
    retval = getparam(t, "head")
  elif tn == "la-num-card":
    num = getparam(t, "num")
    if num == "1":
      retval = u"ūnus"
    elif num == "2":
      retval = "duo"
    elif num == "3":
      retval = u"trēs"
    elif num == "M":
      retval = u"mīlle"
    elif num == "C":
      retval = getparam(t, "1")
      if retval:
        retval = retval + u"ī"
    elif num:
      pagemsg("WARNING: Unrecognized value for num: %s" % num)
      retval = getparam(t, "1")
    else:
      retval = getparam(t, "1")
  elif tn == "la-gerund":
    retval = getparam(t, "head") or (getparam(t, "1") + "um")
  elif tn == "la-letter":
    retval = pagename
  elif tn == "la-prep":
    retval = getparam(t, "head")
  elif tn in la_nonlemma_headword_templates or tn in la_misc_headword_templates:
    retval = getparam(t, "head") or getparam(t, "1")
  else:
    pagemsg("WARNING: Unrecognized headword template %s" % unicode(t))
    retval = ""
  return retval or pagename

# Return the length of FULL that matches STEM, even with mismatches in
# macrons and breves.
def synchronize_stems(full, stem):
  i = 0
  j = 0
  while i < len(full) and j < len(stem):
    ok = False
    if full[i] == stem[j] or remove_macrons(full[i]) == remove_macrons(stem[j]):
      i += 1
      j += 1
      ok = True
    # If there's both a macron and a breve at the end of the stem,
    # we need to skip past the breve.
    if i < len(full) and full[i] in combining_accents:
      i += 1
      ok = True
    if j < len(stem) and stem[j] in combining_accents:
      j += 1
      ok = True
    if not ok:
      return False
  if j < len(stem):
    return False
  return i
