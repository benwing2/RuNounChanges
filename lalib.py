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


la_noun_decl_templates = {
  "la-decl-1st",
  "la-decl-1st-abus",
  "la-decl-1st-am",
  "la-decl-1st-Greek",
  "la-decl-1st-Greek-Ma",
  "la-decl-1st-Greek-Me",
  "la-decl-2nd",
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
  '1st-abus': ('1', 'abus'),
  '1st-am': ('1', 'am'),
  '1st-Greek': ('1', 'Greek'),
  '1st-Greek-Ma': ('1', 'Greek-Ma'),
  '1st-Greek-Me': ('1', 'Greek-Me'),
  '2nd': '2',
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
  '4th-argo': ('4', 'argo'),
  '4th-echo': ('4', 'echo'),
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
    errandpagemsg("Template %s not a recognized adjective declension template" % template)
    return None
  result = expand_text(generate_template)
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

def generate_noun_forms(template, errandpagemsg, expand_text):

  def generate_noun_forms_prefix(m):
    if m.group(1) in la_noun_decl_suffix_to_decltype:
      declspec = la_noun_decl_suffix_to_decltype[m.group(1)]
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

def generate_infl_forms(pos, template, errandpagemsg, expand_text):
  if pos == 'noun':
    return generate_noun_forms(template, errandpagemsg, expand_text)
  elif pos == 'verb':
    return generate_verb_forms(template, errandpagemsg, expand_text)
  elif pos == 'adj':
    return generate_adj_forms(template, errandpagemsg, expand_text)
  else:
    errandpagemsg("WARNING: Bad pos=%s, expected noun/verb/adj")
    return None

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
    if i < len(full) and full[i] == u'\u0306':
      i += 1
      ok = True
    if j < len(stem) and stem[j] == u'\u0306':
      j += 1
      ok = True
    if not ok:
      return False
  if j < len(stem):
    return False
  return i
