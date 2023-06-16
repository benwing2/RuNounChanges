# !/usr/bin/env python
# -*- coding: utf-8 -*-

import re

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def find_latin_section(text, pagemsg):
  return blib.find_modifiable_lang_section(text, "Latin", pagemsg)

la_infl_templates = {
  "la-ndecl",
  "la-adecl",
  "la-conj",
  "la-decl-gerund",
}

la_adj_headword_templates = {
  "la-adj",
  "la-adj-comp",
  "la-adj-sup",
}

la_adv_headword_templates = {
  "la-adv",
  "la-adv-comp",
  "la-adv-sup",
}

la_suffix_headword_templates = {
  "la-suffix",
  "la-suffix-adj",
  "la-suffix-adv",
  "la-suffix-noun",
  "la-suffix-verb",
}

la_num_headword_templates = {
  "la-num-adj",
  "la-num-noun",
}

la_nonlemma_headword_templates = {
  "la-adj-form",
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
  "la-det",
  "la-diacritical mark",
  "la-gerund",
  "la-interj",
  "la-phrase",
  "la-letter",
  "la-noun",
  "la-part",
  "la-pronoun",
  "la-proper noun",
  "la-prep",
  "la-punctuation mark",
  "la-verb",
}

la_lemma_headword_templates = (
  la_adj_headword_templates |
  la_adv_headword_templates |
  la_suffix_headword_templates |
  la_num_headword_templates |
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
  "adverb form",
  "determiner form",
  "gerund form",
  "noun form",
  "numeral form",
  "participle form",
  "pronoun form",
  "proper noun form",
  "suffix form",
  "verb form",
}

la_poses = la_lemma_poses | la_nonlemma_poses

la_infl_of_templates = {
  "inflection of",
  "infl of",
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
  (u"gō", "gin"),
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
      return adv[:-len(suffix)] + newsuff, True
  return adv, False

def generate_adj_forms(template, errandpagemsg, expand_text, return_raw=False,
    include_linked=False):

  if template.startswith("{{la-adecl|"):
    generate_template = re.sub(r"^\{\{la-adecl\|", "{{la-generate-adj-forms|",
        template)
  else:
    errandpagemsg("Template %s not a recognized adjective declension template" % template)
    return None
  result = expand_text(generate_template)
  if return_raw:
    return None if result is False else result
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  args = blib.split_generate_args(result)
  if not include_linked:
    args = {k: v for k, v in args.iteritems() if not k.startswith("linked_")}
  # Add missing feminine forms if needed
  augmented_args = {}
  for key, form in args.iteritems():
    augmented_args[key] = form
    if key.endswith("_m"):
      equiv_fem = key[:-2] + "_f"
      if equiv_fem not in args:
        augmented_args[equiv_fem] = form
  return augmented_args

def generate_noun_forms(template, errandpagemsg, expand_text, return_raw=False,
  include_linked=False):

  if template.startswith("{{la-ndecl|"):
    generate_template = re.sub(r"^\{\{la-ndecl\|", "{{la-generate-noun-forms|",
        template)
  else:
    errandpagemsg("Template %s not a recognized noun declension template" % template)
    return None
  result = expand_text(generate_template)
  if return_raw:
    return None if result is False else result
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  args = blib.split_generate_args(result)
  if not include_linked:
    args = {k: v for k, v in args.iteritems() if not k.startswith("linked_")}
  return args

def generate_verb_forms(template, errandpagemsg, expand_text, return_raw=False,
    include_linked=False, include_props=False, add_sync_forms=False):
  if template.startswith("{{la-conj|"):
    if include_props:
      generate_template = re.sub(r"^\{\{la-conj\|", "{{la-generate-verb-props|",
          template)
    else:
      generate_template = re.sub(r"^\{\{la-conj\|", "{{la-generate-verb-forms|",
          template)
  else:
    errandpagemsg("Template %s not a recognized conjugation template" % template)
    return None
  result = expand_text(generate_template)
  if return_raw:
    return None if result is False else result
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  args = blib.split_generate_args(result)
  if not include_linked:
    args = {k: v for k, v in args.iteritems() if not k.startswith("linked_")}
  def augment_with_sync_forms(forms):
    forms = forms.split(",")
    augmented_forms = []
    for form in forms:
      augmented_forms.append(form)
      if re.search(u"(vi(stī|stis)|vērunt|ver(am|ās|at|āmus|ātis|ant|ō|im|[iī]s|it|[iī]mus|[iī]tis|int)|viss(e|em|ēs|et|ēmus|ētis|ent))$", form):
        augmented_forms.append(re.sub(u"^(.*)v[ieē]", r"\1", form))
    return ",".join(augmented_forms)
  if add_sync_forms:
    args = {k: augment_with_sync_forms(v) for k, v in args.iteritems()}
  return args

def generate_infl_forms(pos, template, errandpagemsg, expand_text,
    return_raw=False, include_linked=False, include_props=False,
    add_sync_verb_forms=False):
  if pos in ['noun', 'pn']:
    return generate_noun_forms(template, errandpagemsg, expand_text, return_raw,
        include_linked)
  elif pos == 'verb':
    return generate_verb_forms(template, errandpagemsg, expand_text, return_raw,
        include_linked, include_props, add_sync_forms=add_sync_verb_forms)
  elif pos in ['adj', 'nounadj', 'numadj', 'part']:
    return generate_adj_forms(template, errandpagemsg, expand_text, return_raw,
        include_linked)
  else:
    errandpagemsg("WARNING: Bad pos=%s, expected noun/verb/adj/nounadj/numadj/part" % pos)
    return None

uppercase = u"A-ZĀĒĪŌŪȲĂĔĬŎŬÄËÏÖÜŸ"
lowercase = u"a-zāēīōūȳăĕĭŏŭäëïöüÿ"
vowel = u"aeiouyAEIOUYāēīōūȳăĕĭŏŭäëïöüÿĀĒĪŌŪȲĂĔĬŎŬÄËÏÖÜŸ"

MACRON = u"\u0304" # macron =  ̄
BREVE = u"\u0306" # breve =  ̆
DOUBLE_INV_BREVE = u"\u0361" # double inverted breve
DIAER = u"\u0308" # diaeresis =  ̈

combining_accents = [MACRON, BREVE, DOUBLE_INV_BREVE, DIAER]
combining_accent_str = "".join(combining_accents)

deaccent_mapper = {
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

breves = u'ăĕĭŏŭĂĔĬŎŬ' + BREVE + DOUBLE_INV_BREVE
macrons = u'āēīōūȳĀĒĪŌŪȲ' + MACRON
diaereses = u'äÄëËïÏöÖüÜÿŸ' + DIAER
macrons_breves = macrons + breves
macrons_breves_diaereses = macrons_breves + diaereses

def remove_macrons(text, preserve_diaeresis=False):
  if preserve_diaeresis:
    return re.sub(u'([' + macrons_breves + '])', lambda m: deaccent_mapper[m.group(1)], text)
  else:
    return re.sub(u'([' + macrons_breves_diaereses + '])', lambda m: deaccent_mapper[m.group(1)], text)

def remove_non_macron_accents(text):
  return re.sub(u'([' + breves + diaereses + '])', lambda m: deaccent_mapper[m.group(1)], text)

def is_nonsyllabic(word):
  return not re.search("[" + vowel + "]", word)

parts_to_tags_list = [
  # parts for verbs
  ('1s', ['1', 's']),
  ('2s', ['2', 's']),
  ('3s', ['3', 's']),
  ('1p', ['1', 'p']),
  ('2p', ['2', 'p']),
  ('3p', ['3', 'p']),
  ('actv', ['act']),
  ('pasv', ['pass']),
  ('pres', ['pres']),
  ('impf', ['impf']),
  ('futp', ['fut', 'perf']),
  ('futr', ['fut']),
  ('perf', ['perf']),
  ('plup', ['plup']),
  ('indc', ['ind']),
  ('subj', ['sub']),
  ('impr', ['imp']),
  ('inf', ['inf']),
  ('ptc', ['part']),
  ('ger', ['ger']),
  ('sup', ['sup']),
  ('nom', ['nom']),
  ('gen', ['gen']),
  ('dat', ['dat']),
  ('acc', ['acc']),
  ('abl', ['abl']),
  # additional parts for adjectives
  ('voc', ['voc']),
  ('sg', ['s']),
  ('pl', ['p']),
  ('m', ['m']),
  ('f', ['f']),
  ('n', ['n']),
  # additional parts for nouns
  ('loc', ['loc']),
]
tags_to_parts_list = [(y, x) for x, y in parts_to_tags_list]
parts_to_tags = dict(parts_to_tags_list)

noun_tag_groups = [
  ['nom', 'gen', 'dat', 'acc', 'abl', 'voc', 'loc'],
  ['s', 'p'],
]

adj_tag_groups = [
  ['nom', 'gen', 'dat', 'acc', 'abl', 'voc', 'loc'],
  ['s', 'p'],
  ['m', 'f', 'n'],
]

verb_tag_groups = [
  ['1', '2', '3'],
  ['s', 'p'],
  ['pres', 'impf', 'fut', 'plup'],
  ['perf'],
  ['act', 'pass'],
  ['ind', 'sub', 'imp'],
  ['inf', 'part'],
  ['ger', 'sup'],
  ['nom', 'gen', 'dat', 'acc', 'abl'],
]

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
  'locative': 'loc',
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

# Sort a tag set according to the groups in GROUPS (e.g. one of noun_tag_groups,
# verb_tag_groups, adj_tag_groups). This first canonicalizes the tags.
# If any tag is unrecognized, a warning is printed using PAGEMSG and None
# returned; otherwise the sorted tag set is returned.
def sort_tag_set(tag_set, groups, pagemsg):
  tag_set = canonicalize_tag_set(tag_set)
  tag_to_level = {
    tag: num for num, tag_level in enumerate(groups) for tag in tag_level
  }
  tag_set_with_levels = []
  for tag in tag_set:
    if tag in tag_to_level:
      tag_set_with_levels.append((tag, tag_to_level[tag]))
    else:
      pagemsg("WARNING: Unrecognized tag %s in %s" % (tag, "|".join(tag_set)))
      return None
  return [x for x, num in sorted(tag_set_with_levels, key=lambda tag_and_level: tag_and_level[1])]

def slot_to_tag_set(slot):
  parts = slot.split("_")
  tags = []
  for part in parts:
    tags.extend(parts_to_tags[part])
  return tags

# Convert a tag set to a noun, verb or adj slot. GROUPS is used for sorting
# the tags prior to conversion to slot parts and should be one of
# noun_tag_groups, verb_tag_groups, or adj_tag_groups. If a given canonicalized
# tag cannot be recognized in tags_to_parts_list, a warning is output by
# PAGEMSG and None returned. Otherwise a string (slot) returned. Note that the
# slot might not be a legal slot; this needs to be checked separately.
def tag_set_to_slot(tag_set, groups, pagemsg):
  tag_set = sort_tag_set(tag_set, groups, pagemsg)
  if tag_set is None:
    return None
  parts = []
  i = 0
  while i < len(tag_set):
    for tags, part in tags_to_parts_list:
      #pagemsg("tags=%s, part=%s, i=%s, tag_set[i:i + len(tags)]=%s" % (
      #  tags, part, i, tag_set[i:i + len(tags)]))
      if i + len(tags) <= len(tag_set) and tags == tag_set[i:i + len(tags)]:
        #pagemsg("Appending part=%s" % part)
        parts.append(part)
        i += len(tags)
        break
    else:
      # no break
      pagemsg("WARNING: Unable to recognize tag_set[%s] = %s in %s" %
          (i, tag_set[i], "|".join(tag_set)))
      return None
  return "_".join(parts)

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
  if tn == "la-conj":
    return "verb"
  elif tn == "la-ndecl":
    return "noun"
  elif tn == "la-adecl":
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

def la_get_headword_from_template(t, pagename, pagemsg, expand_text=None):
  if not expand_text:
    def expand_text(tempcall):
      return blib.expand_text(tempcall, pagename, pagemsg, False)
  tn = tname(t)
  if tn in ["la-adj", "la-part", "la-num-adj", "la-suffix-adj", "la-det", "la-pronoun"]:
    retval = blib.fetch_param_chain(t, "lemma", "lemma")
    if not retval:
      retval = getparam(t, "1")
      if "<" in retval or "((" in retval or " " in retval or "-" in retval:
        generate_template = blib.parse_text(str(t)).filter_templates()[0]
        blib.set_template_name(generate_template, "la-generate-adj-forms")
        blib.remove_param_chain(generate_template, "comp", "comp")
        blib.remove_param_chain(generate_template, "sup", "sup")
        blib.remove_param_chain(generate_template, "adv", "adv")
        blib.remove_param_chain(generate_template, "lemma", "lemma")
        rmparam(generate_template, "type")
        # FIXME: This is wrong, if indecl=1 then we shouldn't try to decline it.
        rmparam(generate_template, "indecl")
        rmparam(generate_template, "id")
        rmparam(generate_template, "pos")
        result = expand_text(str(generate_template))
        if not result:
          pagemsg("WARNING: Error generating forms, skipping")
          retval = ""
        else:
          args = blib.split_generate_args(result)
          if "linked_nom_sg_m" in args:
            retval = args["linked_nom_sg_m"]
          elif "linked_nom_pl_m" in args:
            retval = args["linked_nom_pl_m"]
          else:
            pagemsg("WARNING: Can't locate lemma in {{la-generate-adj-forms}} result: generate_template=%s, result=%s" % (
              str(generate_template), result))
            retval = ""
          retval = retval.split(",")
      else:
        retval = re.sub("/.*", "", retval)
  elif tn in ["la-noun", "la-num-noun", "la-suffix-noun", "la-proper noun"]:
    retval = blib.fetch_param_chain(t, "lemma", "lemma")
    if not retval:
      generate_template = blib.parse_text(str(t)).filter_templates()[0]
      blib.set_template_name(generate_template, "la-generate-noun-forms")
      blib.remove_param_chain(generate_template, "lemma", "lemma")
      blib.remove_param_chain(generate_template, "m", "m")
      blib.remove_param_chain(generate_template, "f", "f")
      blib.remove_param_chain(generate_template, "g", "g")
      rmparam(generate_template, "type")
      # FIXME: This is wrong, if indecl=1 then we shouldn't try to decline it.
      rmparam(generate_template, "indecl")
      rmparam(generate_template, "id")
      rmparam(generate_template, "pos")
      result = expand_text(str(generate_template))
      if not result:
        pagemsg("WARNING: Error generating forms, skipping")
        retval = ""
      else:
        args = blib.split_generate_args(result)
        if "linked_nom_sg" in args:
          retval = args["linked_nom_sg"]
        elif "linked_nom_pl" in args:
          retval = args["linked_nom_pl"]
        else:
          pagemsg("WARNING: Can't locate lemma in {{la-generate-noun-forms}} result: generate_template=%s, result=%s" % (
            str(generate_template), result))
          retval = ""
        retval = retval.split(",")
  elif tn in ["la-verb", "la-suffix-verb"]:
    retval = blib.fetch_param_chain(t, "lemma", "lemma")
    if not retval:
      generate_template = blib.parse_text(str(t)).filter_templates()[0]
      blib.set_template_name(generate_template, "la-generate-verb-forms")
      rmparam(generate_template, "id")
      result = expand_text(str(generate_template))
      if not result:
        pagemsg("WARNING: Error generating forms, skipping")
        retval = ""
      else:
        args = blib.split_generate_args(result)
        for slot in ["linked_1s_pres_actv_indc", "linked_3s_pres_actv_indc",
            "linked_1s_perf_actv_indc", "linked_3s_perf_actv_indc"]:
          if slot in args:
            retval = args[slot]
            break
        else:
          # no break
          pagemsg("WARNING: Can't locate lemma in {{la-generate-verb-forms}} result: generate_template=%s, result=%s" % (
            str(generate_template), result))
          retval = ""
        retval = retval.split(",")
  elif tn in la_adj_headword_templates or tn in la_adv_headword_templates or (
    tn in ["la-suffix", "la-suffix-adv", "la-gerund"]
  ):
    retval = getparam(t, "1")
  elif tn == "la-letter":
    retval = pagename
  elif tn in ["head", "la-prep"]:
    retval = blib.fetch_param_chain(t, "head", "head")
  elif tn in la_nonlemma_headword_templates or tn in la_misc_headword_templates:
    retval = blib.fetch_param_chain(t, "1", "head")
  else:
    pagemsg("WARNING: Unrecognized headword template %s" % str(t))
    retval = ""
  retval = retval or pagename
  if type(retval) is not list:
    retval = [retval]
  return retval

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

def find_defns(text):
  return blib.find_defns(text, 'la')

def slot_matches_spec(slot, spec):
  if spec == "all":
    return True
  elif spec.startswith("!"):
    notspecs = spec[1:].split("+")
    for notspec in notspecs:
      if re.search(notspec, slot):
        return False
    return True
  elif spec == "allbutnomsgn":
    return slot != "nom_sg_n"
  elif spec == "firstpart":
    return slot not in ["futr_actv_ptc", "futr_actv_inf", "futr_pasv_inf"] and (
      "pres" in slot or "impf" in slot or "futr" in slot or "ger" in slot
    )
  elif spec in ["pasv", "pass"]:
    return slot != "perf_pasv_ptc" and "pasv" in slot
  elif spec in ["nonimperspasv", "nonimperspass"]:
    return slot != "perf_pasv_ptc" and "pasv" in slot and (
      "1s" in slot or "1p" in slot or "2s" in slot or "2p" in slot or "3p" in slot
    )
  elif spec in ["12pasv", "12pass"]:
    return slot != "perf_pasv_ptc" and "pasv" in slot and (
      "1s" in slot or "1p" in slot or "2s" in slot or "2p" in slot
    )
  elif spec == "passnofpp":
    return slot not in ["perf_pasv_ptc", "futr_pasv_ptc"] and "pasv" in slot
  elif spec == "perf":
    return (slot not in ["perf_actv_ptc", "perf_pasv_ptc"] and
      re.search("(perf|plup|futp)", slot)
    )
  elif spec in ["perf-pasv", "perf-pass"]:
    return "perf" in slot and "pasv" in slot
  elif spec == "sup":
    return "sup" in slot or slot in ["perf_actv_ptc", "perf_pasv_ptc", "futr_actv_ptc"]
  elif spec == "supnofap":
    return "sup" in slot or slot in ["perf_actv_ptc", "perf_pasv_ptc"]
  elif spec == "ger":
    return "ger" in slot
  elif spec in ["imp", "impr"]:
    return "impr" in slot
  elif spec == "fem":
    return re.search("_f$", slot)
  elif spec == "neut":
    return re.search("_n$", slot)
  elif spec == "pl":
    return re.search("_pl$", slot)
  elif "_" not in spec:
    raise ValueError("Unrecognized spec: %s" % spec)
  else:
    return False

def find_heads_and_defns(text, pagemsg):
  retval = find_latin_section(text, pagemsg)
  if retval is None:
    return None

  sections, j, secbody, sectail, has_non_latin = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  parsed_subsections = [None] * len(subsections)

  headwords = []
  pronun_sections = []
  etym_sections = []

  most_recent_headword = None
  most_recent_pronun_section = None
  most_recent_etym_section = None

  def new_headword(header, level, subsection, head_template, is_lemma):
    retval = {
      'head_template': head_template,
      'header': header,
      'is_lemma': is_lemma,
      'infl_templates': [],
      'infl_of_templates': [],
      'subsection': subsection,
      'level': level,
      'pronun_section': most_recent_pronun_section,
      'etym_section': most_recent_etym_section,
    }
    if most_recent_pronun_section:
      most_recent_pronun_section['headwords'].append(retval)
    if most_recent_etym_section:
      most_recent_etym_section['headwords'].append(retval)
    return retval

  def new_pronun_section(header, level, subsection):
    return {
      'header': header,
      'pronun_templates': [],
      'headwords': [],
      'subsection': subsection,
      'level': level,
    }

  def new_etym_section(header, level, subsection):
    return {
      'header': header,
      'headwords': [],
      'subsection': subsection,
      'level': level,
    }

  for k in range(len(subsections)):
    if k < 2 or (k % 2) == 1:
      parsed_subsections[k] = blib.parse_text(subsections[k])
      continue
    m = re.search("^(==+)([^=\n]+)", subsections[k - 1])
    level = len(m.group(1))
    header = m.group(2)
    headword_templates_in_section = []

    if most_recent_headword and most_recent_headword['level'] >= level:
      headwords.append(most_recent_headword)
      most_recent_headword = None

    is_pronun_section = header.startswith('Pronunciation')
    if is_pronun_section:
      if most_recent_pronun_section:
        pronun_sections.append(most_recent_pronun_section)
      most_recent_pronun_section = new_pronun_section(header, level, k)
    elif most_recent_pronun_section and most_recent_pronun_section['level'] > level:
      pronun_sections.append(most_recent_pronun_section)
      most_recent_pronun_section = None

    is_etym_section = header.startswith('Etymology')
    if is_etym_section:
      if most_recent_etym_section:
        etym_sections.append(most_recent_etym_section)
      most_recent_etym_section = new_etym_section(header, level, k)
    elif most_recent_etym_section and most_recent_etym_section['level'] > level:
      etym_sections.append(most_recent_etym_section)
      most_recent_etym_section = None

    parsed = blib.parse_text(subsections[k])
    parsed_subsections[k] = parsed
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "la-IPA":
        if is_pronun_section:
          most_recent_pronun_section['pronun_templates'].append(t)
        else:
          pagemsg("WARNING: Pronunciation template %s in %s section, not pronunciation section" % (
            str(t), header))
      elif tn in la_headword_templates or tn == "head":
        if tn == "head":
          if getparam(t, "1") != "la":
            pagemsg("WARNING: Wrong-language {{head}} template in Latin section: %s" % str(t))
            continue
          head_pos = getparam(t, "2")
          if head_pos not in la_poses:
            pagemsg("WARNING: Unrecognized part of speech %s" % head_pos)
        if headword_templates_in_section:
          pagemsg("WARNING: Found additional headword template in same section: %s" % str(t))
          headwords.append(most_recent_headword)
        elif most_recent_headword:
          pagemsg("WARNING: Found headword template nested under previous one: %s" % str(t))
          headwords.append(most_recent_headword)
        most_recent_headword = new_headword(header, level, k, t,
          tn in la_lemma_headword_templates or (
            tn == "head" and head_pos in la_lemma_poses))
        headword_templates_in_section.append(t)
      elif tn in la_infl_templates:
        if not most_recent_headword:
          pagemsg("WARNING: Found inflection template not under headword template: %s" % str(t))
        else:
          most_recent_headword['infl_templates'].append(t)
      elif tn in la_infl_of_templates:
        if not most_recent_headword:
          pagemsg("WARNING: Found inflection-of template not under headword template: %s" % str(t))
        else:
          most_recent_headword['infl_of_templates'].append(t)

  if most_recent_headword:
    headwords.append(most_recent_headword)
  if most_recent_pronun_section:
    pronun_sections.append(most_recent_pronun_section)
  if most_recent_etym_section:
    etym_sections.append(most_recent_etym_section)


  return (
    sections, j, secbody, sectail, has_non_latin, subsections,
    parsed_subsections, headwords, pronun_sections, etym_sections
  )
