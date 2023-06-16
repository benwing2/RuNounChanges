#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, getrmparam, tname, msg, errandmsg, site, bool_param_is_true

import lalib

from convert_la_adj import adj_decl_and_subtype_to_props

# FIXME: Out of date script, not needed any more, might not still work.

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

old_la_noun_decl_templates = set(
  'la-decl-%s' % k for k in la_noun_decl_suffix_to_decltype
)

def generate_old_noun_forms(template, errandpagemsg, expand_text, return_raw=False,
  include_linked=False):

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

  if template.startswith("{{la-ndecl|"):
    generate_template = re.sub(r"^\{\{la-ndecl\|", "{{la-generate-noun-forms|",
        template)
  else:
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
  args = blib.split_generate_args(result)
  if not include_linked:
    args = {k: v for k, v in args.iteritems() if not k.startswith("linked_")}
  return args

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def generate_old_forms():
    if origt.startswith("{{la-decl-multi|"):
      old_generate_template = re.sub(r"^\{\{la-decl-multi\|", "{{la-generate-multi-forms|", origt)
      old_result = expand_text(old_generate_template)
      if not old_result:
        return None
      return old_result
    else:
      return generate_old_noun_forms(origt, errandpagemsg, expand_text, return_raw=True)

  def generate_new_forms():
    if newt.startswith("{{la-ndecl|"):
      new_generate_template = re.sub(r"^\{\{la-ndecl\|", "{{User:Benwing2/la-new-generate-noun-forms|", newt)
    else:
      new_generate_template = re.sub(r"^\{\{la-adecl\|", "{{User:Benwing2/la-new-generate-adj-forms|", newt)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    # Omit linked_* variants, which won't be present in the old forms
    new_result = "|".join(x for x in new_result.split("|") if not x.startswith("linked_"))
    return new_result

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg)

def compute_noun_lemma_and_subtypes(decl, stem1, stem2, num, stem_suffix, pl_suffix,
    to_auto, pagemsg, origt):
  if type(to_auto) is not tuple:
    to_auto = to_auto(stem1, stem2, num)
  num_originally_pl = False
  if num == "pl" and pl_suffix:
    num_originally_pl = True
    lemma = stem1 + pl_suffix
    num = None
  else:
    lemma = stem1 + stem_suffix
  subtypes = []
  for subtype in to_auto:
    if subtype.startswith('-'):
      pagemsg("WARNING: Inferred canceling subtype %s, need to verify: %s" % (subtype, origt))
    subtypes.append(subtype)
  if re.search(u"^[A-ZĀĒĪŌŪȲĂĔĬŎŬ]", lemma):
    # Proper nouns in -polis that use {{la-decl-3rd-polis}} won't specify
    # num=sg because the declension template itself specifies num=sg when
    # invoking the module. Meanwhile the module itself specifies num=sg for
    # indeclinable nouns and certain irregular nouns. In all these cases,
    # we should not add .both.
    auto_sg = (
      decl == "3" and lemma.endswith("polis") and "-polis" not in subtypes or
      decl == "indecl" or
      decl == "irreg" and lemma in ["Deus", u"Iēsus", u"Jēsus", u"Callistō", u"Themistō"]
    )
    if not num and not num_originally_pl and not auto_sg:
      num = "both"
    elif num == "sg":
      num = None
  if num:
    subtypes.append(num)
  if stem2:
    if (decl == "3" and lalib.infer_3rd_decl_stem(lemma) == stem2 or
        decl == "2" and lemma == stem2):
      stem2 = ""
  return lemma, stem2, subtypes

def convert_la_decl_multi_to_new(t, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
  origt = str(t)
  segments = re.split(r"([^<> ]+<[^<>]*>)", getparam(t, "1"))
  g = getrmparam(t, "g")
  if g:
    gender_map = {"m": "M", "f": "F", "n": "N"}
    if g not in gender_map:
      errandpagemsg("WARNING: Unrecognized gender g=%s" % g)
      return None
    g = gender_map[g]
  lig = getparam(t, "lig")
  um = getrmparam(t, "um")
  if um:
    um = um.split(",")
  else:
    um = []
  num = getrmparam(t, "num")
  for i in range(1, len(segments) - 1, 2):
    m = re.search("^([^<> ]+)<([^<>]*)>$", segments[i])
    stem_spec, decl_and_subtype_spec = m.groups()
    stems = stem_spec.split("/")
    if len(stems) == 1:
      stem1 = stems[0]
      stem2 = ""
    elif len(stems) == 2:
      stem1, stem2 = stems
    else:
      errandpagemsg("WARNING: Too many stems: %s" % origt)
      return None
    decl_and_subtypes = decl_and_subtype_spec.split(".")
    if len(decl_and_subtypes) == 1:
      decl = decl_and_subtypes[0]
      specified_subtypes = ()
    elif len(decl_and_subtypes) == 2:
      decl, specified_subtypes = decl_and_subtypes
      specified_subtypes = tuple(specified_subtypes.split("-"))
    else:
      errandpagemsg("WARNING: Too many subtypes: %s" % origt)
      return None
    if decl == "i":
      decl = "irreg"
    sufn = False
    if "n" in specified_subtypes:
      sufn = True
      specified_subtypes = tuple(x for x in specified_subtypes if x != "n")
    if decl == "":
      if specified_subtypes:
        errandpagemsg("WARNING: Blank decl class with subtypes: %s" % origt)
        return None
      lemma = stem1
      subtypes = []
      # Do nothing else, we'll handle a blank decl specially below by
      # wrapping in ((...))
    elif decl in adj_decl_and_subtype_to_props:
      adj_key, adj_compute_props = adj_decl_and_subtype_to_props[decl]
      lemma, stem2, decl, subtypes = (
        adj_compute_props(stem1, stem2, decl, list(specified_subtypes), num, g, False,
          pagetitle, pagemsg)
      )
      # No point in attaching .sg or .pl to modifying adjectives; they
      # inherit the surrounding number restriction
      subtypes = [x for x in subtypes if x not in ["pl", "sg"]]
      decl += "+"
    else:
      if g == "N" and "N" not in specified_subtypes:
        specified_subtypes = ("N",) + specified_subtypes
      lookup_key = (decl, specified_subtypes)
      if lookup_key not in noun_decl_and_subtype_to_props:
        errandpagemsg("WARNING: Lookup key %s not found: %s" % (
          lookup_key, origt))
        return None
      auto_num, stem_suffix, pl_suffix, to_auto = noun_decl_and_subtype_to_props[lookup_key]
      lemma, stem2, subtypes = compute_noun_lemma_and_subtypes(decl, stem1, stem2, num, stem_suffix, pl_suffix, to_auto, pagemsg, origt)
      base_and_detected_subtypes = expand_text("{{#invoke:User:Benwing2/la-noun|detect_subtype|%s|%s|%s|%s}}" % (lemma, stem2, decl, ".".join(subtypes)))
      base, detected_subtypes = base_and_detected_subtypes.split("|")
      detected_subtypes = detected_subtypes.split(".")
      if (g == "N" and ("M" in detected_subtypes or "F" in detected_subtypes or "N" not in detected_subtypes and "N" not in subtypes) or
          (g == "M" or g == "F") and ("N" in detected_subtypes)):
        errandpagemsg("WARNING: Incompatible gender specification: g=%s, subtypes=%s, detected_subtypes=%s: %s" % (
          g, ".".join(subtypes), ".".join(detected_subtypes), origt))
        return None
      if (g == "M" or g == "F") and g not in detected_subtypes:
        # Add the gender explicitly, and remove any -N specification, which
        # becomes redundant.
        subtypes = [g] + [x for x in subtypes if x != "-N"]
      loc = getrmparam(t, "loc")
      if bool_param_is_true(loc):
        subtypes.append("loc")
      if str((i + 1) / 2) in um:
        subtypes.append("genplum")
    if sufn:
      subtypes.append("sufn")
    if bool_param_is_true(lig):
      subtypes.append("lig")
    if stem2:
      lemma += "/" + stem2
    if decl:
      subtypes = [decl] + subtypes
    if not subtypes:
      lemma = "((%s))" % lemma
    else:
      lemma += "<%s>" % ".".join(subtypes)
    segments[i] = lemma
  blib.set_template_name(t, "la-ndecl" if g else "la-adecl")
  t.add("1", "".join(segments))
  pagemsg("Replaced %s with %s" % (origt, str(t)))
  if compare_new_and_old_templates(origt, str(t), pagetitle, pagemsg, errandpagemsg):
    return t
  else:
    return None

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
  origt = str(t)
  tn = tname(t)
  m = re.search(r"^la-decl-(.*)$", tn)
  if not m:
    pagemsg("WARNING: Something wrong, can't parse noun decl template name: %s" % tn)
    return None
  decl_suffix = m.group(1)
  if decl_suffix not in la_noun_decl_suffix_to_decltype:
    pagemsg("WARNING: Unrecognized noun decl template name: %s" % tn)
    return None
  retval = la_noun_decl_suffix_to_decltype[decl_suffix]
  if retval is None:
    pagemsg("WARNING: Unable to convert template: %s" % str(t))
    return None
  declspec, stem_suffix, pl_suffix, to_auto = retval
  if type(declspec) is tuple:
    declspec = declspec[0]
  stem1 = getparam(t, "1").strip()
  stem2 = getparam(t, "2").strip()
  num = getrmparam(t, "num")
  lemma, stem2, subtypes = compute_noun_lemma_and_subtypes(declspec, stem1, stem2, num, stem_suffix, pl_suffix, to_auto, pagemsg, origt)
  loc = getrmparam(t, "loc")
  if bool_param_is_true(loc):
    subtypes.append("loc")
  lig = getrmparam(t, "lig")
  if bool_param_is_true(lig):
    subtypes.append("lig")
  um = getrmparam(t, "um")
  genplum = getrmparam(t, "genplum")
  if bool_param_is_true(um) or bool_param_is_true(genplum):
    subtypes.append("genplum")
  sufn = getrmparam(t, "n")
  if bool_param_is_true(sufn):
    subtypes.append("sufn")
  blib.set_template_name(t, "la-ndecl")
  # Fetch all params
  named_params = []
  for param in t.params:
    pname = str(param.name)
    if pname.strip() in ["1", "2", "noun"]:
      continue
    named_params.append((pname, param.value, param.showkey))
  # Erase all params
  del t.params[:]
  # Put back params
  if stem2:
    lemma += "/" + stem2
  lemma += "<%s>" % ".".join([declspec] + subtypes)
  t.add("1", lemma)
  for name, value, showkey in named_params:
    t.add(name, value, showkey=showkey, preserve_spacing=False)
  pagemsg("Replaced %s with %s" % (origt, str(t)))
  if compare_new_and_old_templates(origt, str(t), pagetitle, pagemsg, errandpagemsg):
    return t
  else:
    return None

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "la-decl-multi":
      t = convert_la_decl_multi_to_new(t, pagetitle, pagemsg, errandpagemsg)
      if t:
        notes.append("converted {{la-decl-multi}} to {{%s}}" % tname(t))
      else:
        return None, None
    elif tn in old_la_noun_decl_templates:
      if convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
        notes.append("converted {{%s}} to {{la-ndecl}}" % tn)
      else:
        return None, None

  return str(parsed), notes

parser = blib.create_argparser("Convert Latin noun decl templates to new form",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Latin nouns", "Latin proper nouns"], edit=True)
