#!/usr/bin/env python
#coding: utf-8

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import uklib

import find_regex


def param_is_end_stressed(param, possible_endings=[]):
  values = [uklib.add_monosyllabic_stress(word) for word in re.split(", *", param)]
  if any(uklib.is_unstressed(v) for v in values):
    return "unknown"
  if any(uklib.is_mixed_stressed(v, possible_endings) for v in values):
    return "mixed"
  end_stresses = [uklib.is_end_stressed(v, possible_endings) for v in values]
  if all(end_stresses):
    return True
  if any(end_stresses):
    return "mixed"
  return False

def is_undefined(word):
  return word in ["", "-", u"-", u"—"]

stress_patterns = [
  ("a", {"inssg": False, "accsg": None, "nompl": False, "locpl": False}),
  ("b", {"inssg": True, "accsg": True, "nompl": True, "locpl": True}),
  ("c", {"inssg": False, "accsg": None, "nompl": True, "locpl": True}),
  ("d", {"inssg": True, "accsg": True, "nompl": False, "locpl": False}),
  ("d'", {"inssg": True, "accsg": False, "nompl": False, "locpl": False}),
  ("e", {"inssg": False, "accsg": None, "nompl": False, "locpl": True}),
  ("f", {"inssg": True, "accsg": True, "nompl": False, "locpl": True}),
  ("f'", {"inssg": True, "accsg": False, "nompl": False, "locpl": True}),
]

genitive_singular_endings = [u"а", u"я", u"у", u"ю", u"і", u"ї", u"и"]
dative_singular_endings = [u"у", u"ю", u"ові", u"еві", u"єві", u"і", u"ї"]
instrumental_singular_endings = [u"ом", u"ем", u"єм", u"ям", u"ою", u"ею", u"єю", u"ю"]
locative_singular_endings = [u"у", u"ю", u"ові", u"еві", u"єві", u"і", u"ї"]
vocative_singular_endings = [u"е", u"є", u"у", u"ю", u"о", u"я"]
nominative_plural_endings = [u"і", u"ї", u"и", u"а", u"я", u"е"]
genitive_plural_endings = [u"ей", u"єй", u"ів", u"їв", u"ь", ""]
instrumental_plural_endings = [u"ами", u"ями", u"ьми"]

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  head = None
  plurale_tantum = False
  animacy = "unknown"
  gender = "unknown"
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "uk-noun":
      head = getparam(t, "1")
      gender_and_animacy = getparam(t, "2")
      plurale_tantum = False
      animacy = "unknown"
      gender = "unknown"
      if gender_and_animacy:
        gender_and_animacy_parts = gender_and_animacy.split("-")
        gender = gender_and_animacy_parts[0]
        if len(gender_and_animacy_parts) > 1:
          animacy = gender_and_animacy_parts[1]
        if len(gender_and_animacy_parts) > 2 and gender_and_animacy_parts[2] == "p":
          plurale_tantum = True
      if getparam(t, "g2"):
        pagemsg("WARNING: Multiple genders: %s" % unicode(t))

    def fetch(param):
      val = getparam(t, param).strip()
      return blib.remove_links(val)

    def matches(is_end_stressed, should_be_end_stressed):
      return (is_end_stressed == "mixed" or should_be_end_stressed is None or
          is_end_stressed == should_be_end_stressed)

    def fetch_endings(param, endings):
      paramval = fetch(param)
      values = re.split(", *", paramval)
      found_endings = []
      for v in values:
        v = v.replace(uklib.AC, "")
        for ending in endings:
          if v.endswith(ending):
            found_endings.append(ending)
            break
        else: # no break
          pagemsg("WARNING: Couldn't recognize ending for %s=%s: %s" % (
            param, paramval, unicode(t)))
      return ":".join(found_endings)

    def canon(val):
      return re.sub(", *", "/", val)
    def stress(endstressed):
      return (
        "endstressed" if endstressed == True else
        "stemstressed" if endstressed == False else "mixed"
      )

    if tn == "uk-decl-noun":
      nom_sg = fetch("1")
      gen_sg = fetch("3")
      gen_sg_end_stressed = param_is_end_stressed(gen_sg)
      dat_sg = fetch("5")
      dat_sg_end_stressed = param_is_end_stressed(dat_sg, dative_singular_endings)
      acc_sg = fetch("7")
      acc_sg_end_stressed = param_is_end_stressed(acc_sg)
      ins_sg = fetch("9")
      ins_sg_end_stressed = param_is_end_stressed(ins_sg, instrumental_singular_endings)
      loc_sg = fetch("11")
      loc_sg_end_stressed = param_is_end_stressed(loc_sg, locative_singular_endings)
      voc_sg = fetch("13")
      voc_sg_end_stressed = param_is_end_stressed(voc_sg)
      nom_pl = fetch("2")
      nom_pl_end_stressed = param_is_end_stressed(nom_pl)
      gen_pl = fetch("4")
      gen_pl_end_stressed = param_is_end_stressed(gen_pl)
      ins_pl = fetch("10")
      ins_pl_end_stressed = param_is_end_stressed(ins_pl, instrumental_plural_endings)
      loc_pl = fetch("12")
      loc_pl_end_stressed = param_is_end_stressed(loc_pl)
      if (gen_sg_end_stressed == "unknown" or
          acc_sg_end_stressed == "unknown" or
          voc_sg_end_stressed == "unknown" or
          nom_pl_end_stressed == "unknown" or
          loc_pl_end_stressed == "unknown"):
        pagemsg("WARNING: Missing stresses, can't determine accent pattern: %s" % unicode(t))
        continue
      seen_patterns = []
      for pattern, accents in stress_patterns:
        if (matches(ins_sg_end_stressed, accents["inssg"]) and
            matches(acc_sg_end_stressed, accents["accsg"]) and
            matches(nom_pl_end_stressed, accents["nompl"]) and
            matches(loc_pl_end_stressed, accents["locpl"])):
          seen_patterns.append(pattern)
      if "a" in seen_patterns and "b" in seen_patterns:
        seen_patterns = ["a", "b"]
      elif "a" in seen_patterns and "c" in seen_patterns:
        seen_patterns = ["a", "c"]
      gen_sg_endings = fetch_endings("3", genitive_singular_endings)
      dat_sg_endings = fetch_endings("5", dative_singular_endings)
      ins_sg_endings = fetch_endings("9", instrumental_singular_endings)
      loc_sg_endings = fetch_endings("11", locative_singular_endings)
      voc_sg_endings = fetch_endings("13", vocative_singular_endings)
      nom_pl_endings = fetch_endings("2", nominative_plural_endings)
      gen_pl_endings = fetch_endings("4", genitive_plural_endings)

      pagemsg("%s\tgender:%s\tanimacy:%s\taccent:%s\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tvoc_sg:%s\tgen_pl:%s\tnumber:both\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tvoc_sg:%s\tnom_pl:%s\tgen_pl:%s\t| %s || \"?\" || %s || %s || %s || %s || %s || %s || || " % (
        head, gender, animacy, ":".join(seen_patterns),
        stress(gen_sg_end_stressed), stress(dat_sg_end_stressed),
        stress(loc_sg_end_stressed), stress(voc_sg_end_stressed),
        stress(gen_pl_end_stressed),
        gen_sg_endings, dat_sg_endings, loc_sg_endings, voc_sg_endings,
        nom_pl_endings, gen_pl_endings, canon(nom_sg), canon(gen_sg),
        canon(loc_sg), canon(voc_sg), canon(nom_pl), canon(gen_pl),
        canon(ins_pl)))

    elif tn == "uk-decl-noun-unc":
      nom_sg = fetch("1")
      gen_sg = fetch("2")
      gen_sg_end_stressed = param_is_end_stressed(gen_sg)
      dat_sg = fetch("3")
      dat_sg_end_stressed = param_is_end_stressed(dat_sg, dative_singular_endings)
      acc_sg = fetch("4")
      acc_sg_end_stressed = param_is_end_stressed(acc_sg)
      ins_sg = fetch("5")
      ins_sg_end_stressed = param_is_end_stressed(ins_sg, instrumental_singular_endings)
      loc_sg = fetch("6")
      loc_sg_end_stressed = param_is_end_stressed(loc_sg, locative_singular_endings)
      voc_sg = fetch("7")
      voc_sg_end_stressed = param_is_end_stressed(voc_sg)
      if (gen_sg_end_stressed == "unknown" or
          acc_sg_end_stressed == "unknown" or
          voc_sg_end_stressed == "unknown"):
        pagemsg("WARNING: Missing stresses, can't determine accent pattern: %s" % unicode(t))
        continue
      seen_patterns = []
      for pattern, accents in stress_patterns:
        if pattern not in ["a", "b", "d'"]:
          continue
        if (matches(ins_sg_end_stressed, accents["inssg"]) and
            matches(acc_sg_end_stressed, accents["accsg"])):
          seen_patterns.append(pattern)
      if "a" in seen_patterns and "b" in seen_patterns:
        seen_patterns = ["a", "b"]
      gen_sg_endings = fetch_endings("2", genitive_singular_endings)
      dat_sg_endings = fetch_endings("3", dative_singular_endings)
      ins_sg_endings = fetch_endings("5", instrumental_singular_endings)
      loc_sg_endings = fetch_endings("6", locative_singular_endings)
      voc_sg_endings = fetch_endings("7", vocative_singular_endings)

      pagemsg("%s\tgender:%s\tanimacy:%s\taccent:%s\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tvoc_sg:%s\tgen_pl:-\tnumber:sg\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tvoc_sg:%s\tnom_pl:-\tgen_pl:-\t| %s || \"?\" || %s || %s || %s || - || - || - || || " % (
        head, gender, animacy, ":".join(seen_patterns),
        stress(gen_sg_end_stressed), stress(dat_sg_end_stressed),
        stress(loc_sg_end_stressed), stress(voc_sg_end_stressed),
        gen_sg_endings, dat_sg_endings, loc_sg_endings, voc_sg_endings,
        canon(nom_sg), canon(gen_sg), canon(loc_sg), canon(voc_sg)))

    elif tn == "uk-decl-noun-pl":
      nom_pl = fetch("1")
      nom_pl_end_stressed = param_is_end_stressed(nom_pl)
      gen_pl = fetch("2")
      gen_pl_end_stressed = param_is_end_stressed(gen_pl)
      ins_pl = fetch("5")
      ins_pl_end_stressed = param_is_end_stressed(ins_pl, instrumental_plural_endings)
      loc_pl = fetch("6")
      loc_pl_end_stressed = param_is_end_stressed(loc_pl)
      if (nom_pl_end_stressed == "unknown" or
          loc_pl_end_stressed == "unknown"):
        pagemsg("WARNING: Missing stresses, can't determine accent pattern: %s" % unicode(t))
        continue
      seen_patterns = []
      for pattern, accents in stress_patterns:
        if pattern not in ["a", "b", "e"]:
          continue
        if (matches(nom_pl_end_stressed, accents["nompl"]) and
            matches(loc_pl_end_stressed, accents["locpl"])):
          seen_patterns.append(pattern)
      if "a" in seen_patterns and "b" in seen_patterns:
        seen_patterns = ["a", "b"]
      nom_pl_endings = fetch_endings("1", nominative_plural_endings)
      gen_pl_endings = fetch_endings("2", genitive_plural_endings)

      pagemsg("%s\tgender:%s\tanimacy:%s\taccent:%s\tgen_sg:-\tdat_sg:-\tloc_sg:-\tvoc_sg:-\tgen_pl:%s\tnumber:pl\tgen_sg:-\tdat_sg:-\tloc_sg:-\tvoc_sg:-\tnom_pl:%s\tgen_pl:%s\t| %s || \"?\" || - || - || - || %s || %s || %s || || " % (
        head, gender, animacy, ":".join(seen_patterns),
        stress(gen_pl_end_stressed),
        nom_pl_endings, gen_pl_endings,
        canon(nom_pl), canon(nom_pl), canon(gen_pl), canon(ins_pl)))


def process_page(page, index):
  pagetitle = unicode(page.title())
  process_text_on_page(index, pagetitle, page.text)


parser = blib.create_argparser("Analyze Ukrainian noun declensions",
  include_pagefile=True)
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.direcfile:
  lines = codecs.open(args.direcfile, "r", "utf-8")
  pagename_and_text = find_regex.yield_text_from_find_regex(lines, args.verbose)
  for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
      get_name=lambda x:x[0]):
    process_text_on_page(index, pagename, text)
else:
  blib.do_pagefile_cats_refs(args, start, end, process_page,
      default_cats=["Ukrainian nouns"])
