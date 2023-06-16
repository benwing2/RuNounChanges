#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import uklib as uk

AC = u"\u0301"

def param_is_end_stressed(param, possible_endings=[]):
  values = [uk.add_monosyllabic_stress(word) for word in re.split(", *", param)]
  if any(uk.is_unstressed(v) for v in values):
    return "unknown"
  if any(uk.is_mixed_stressed(v, possible_endings) for v in values):
    return "mixed"
  end_stresses = [uk.is_end_stressed(v, possible_endings) for v in values]
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
  heads = None
  plurale_tantum = False
  animacy = "unknown"
  gender = "unknown"
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["uk-noun", "uk-proper noun"]:
      heads = blib.fetch_param_chain(t, "1", "head")
      gender_and_animacy = blib.fetch_param_chain(t, "2", "g")
      plurale_tantum = False
      animacy = []
      gender = []
      if gender_and_animacy:
        for ga in gender_and_animacy:
          gender_and_animacy_parts = ga.split("-")
          g = gender_and_animacy_parts[0]
          if g not in gender:
            gender.append(g)
          if len(gender_and_animacy_parts) > 1:
            a = gender_and_animacy_parts[1]
            if a not in animacy:
              animacy.append(a)
          if len(gender_and_animacy_parts) > 2 and gender_and_animacy_parts[2] == "p":
            plurale_tantum = True
      if not animacy:
        animacy = "unknown"
      elif len(animacy) > 1:
        pagemsg("WARNING: Multiple animacies: %s" % ",".join(animacy))
      animacy = animacy[0]
      if not gender:
        gender = "unknown"
      elif set(gender) == {"m", "f"}:
        gender = "MF"
      else:
        if len(gender) > 1:
          pagemsg("WARNING: Multiple genders: %s" % ",".join(gender))
        gender = gender[0]
        if gender in ["m", "f", "n"]:
          gender = gender.upper()
        else:
          pagemsg("WARNING: Unknown gender: %s" % gender)
          gender = "unknown"

    def fetch(param):
      val = getparam(t, param).strip()
      val = blib.remove_links(val)
      vals = re.split(r",\s*", val)
      retval = []
      for v in vals:
        # Remove final footnote symbols are per [[Module:table tools]]
        v = re.sub(ur"[*~@#$%^&+0-9_\u00A1-\u00BF\u00D7\u00F7\u2010-\u2027\u2030-\u205E\u2070-\u20CF\u2100-\u2B5F\u2E00-\u2E3F]*$", "", v)
        retval.append(uk.add_monosyllabic_stress(v))
      return ", ".join(retval)

    def matches(is_end_stressed, should_be_end_stressed):
      return (is_end_stressed == "mixed" or should_be_end_stressed is None or
          is_end_stressed == should_be_end_stressed)

    def fetch_endings(param, endings):
      paramval = fetch(param)
      values = re.split(", *", paramval)
      found_endings = []
      for v in values:
        v = v.replace(uk.AC, "")
        for ending in endings:
          if v.endswith(ending):
            found_endings.append(ending)
            break
        else: # no break
          pagemsg("WARNING: Couldn't recognize ending for %s=%s: %s" % (
            param, paramval, str(t)))
      return ":".join(found_endings)

    def canon(val):
      return re.sub(", *", "/", val)
    def stress(endstressed):
      return (
        "endstressed" if endstressed == True else
        "stemstressed" if endstressed == False else "mixed"
      )
    def check_multi_stressed(maxparam):
      for i in range(1, maxparam + 1):
        val = getparam(t, str(i))
        vals = re.split(r",\s*", val)
        for v in vals:
          if uk.is_multi_stressed(v):
            pagemsg("WARNING: Param %s=%s has multiple stresses: %s" % (
              (str(i), val, str(t))))
          if uk.needs_accents(v):
            pagemsg("WARNING: Param %s=%s has missing stress: %s" % (
              (str(i), val, str(t))))
    def ins_sg_note(ins_sg):
      if re.search(u"[чшжщфвбмпь]$", heads[0]) and gender == "f":
        return "ins_sg=%s " % canon(ins_sg)
      else:
        return ""

    def truncate_extra_forms(form):
      return re.sub(",.*", "", form)

    def infer_animacy(nom_pl, gen_pl, acc_pl):
      nom_pl_vals = set(nom_pl.split(", "))
      gen_pl_vals = set(gen_pl.split(", "))
      acc_pl_vals = set(acc_pl.split(", "))
      if acc_pl_vals == nom_pl_vals:
        return "in"
      elif acc_pl_vals == gen_pl_vals:
        return "pr"
      elif acc_pl_vals == nom_pl_vals | gen_pl_vals:
        return "anml"
      else:
        pagemsg("WARNING: Can't infer animacy: nom_pl=%s, gen_pl=%s, acc_pl=%s" % (
          nom_pl, gen_pl, acc_pl))
        return "unknown"

    def infer_gender(lemma):
      if re.search(u"[ое]́?$", lemma) or re.search(ur"(.)\1я́?$", lemma) or re.search(u"'я́?$", lemma):
        return "N"
      elif re.search(u"[ая]́?$", lemma) or re.search(u"ість$", lemma):
        return "F"
      elif re.search(u"(тель|[еє]́?ць)$", lemma):
        return "M"
      elif re.search(u"ь$", lemma):
        return None
      elif re.search(uk.cons_c + "$", lemma):
        return "M"
      else:
        pagemsg("WARNING: Unrecognized lemma ending: %s" % lemma)
        return None

    def default_stress(lemma, gender, reducible):
      if re.search(u"я́$", lemma) and gender == "N":
        return "b"
      elif re.search(AC + "$", lemma):
        return "d"
      elif reducible and re.search(u"[еоєі]́" + uk.cons_c + u"ь?$", lemma):
        return "b"
      else:
        return "a"

    def apply_vowel_alternation(stem, ialt):
      if ialt == "io":
        modstem = re.sub(u"(.*[лЛ])і(́?" + uk.cons_c + "*)$", ur"\1ьо\2", stem)
        if modstem == stem:
          modstem = re.sub(u"(.*)і(́?" + uk.cons_c + "*)$", ur"\1о\2", stem)
      elif ialt == "ie":
        modstem = re.sub(u"(.*)і(́?" + uk.cons_c + "*)$", ur"\1е\2", stem)
      else:
        assert ialt == "i"
        modstem = re.sub(u"ь?[ое](́?" + uk.cons_c + "*)$", ur"і\1", stem)
      if modstem == stem:
        return None
      return modstem

    def infer_alternations(nom_sg, gen_sg, gen_pl):
      nom_sg = uk.remove_accents(truncate_extra_forms(nom_sg))
      gen_sg = uk.remove_accents(truncate_extra_forms(gen_sg))
      gen_pl = gen_pl and uk.remove_accents(truncate_extra_forms(gen_pl))
      m = re.search(u"^(.*)[аяео]$", nom_sg)
      if m:
        vowel_stem = m.group(1)
        if re.search(uk.vowel_c + "$", vowel_stem):
          vowel_stem += u"й"
        if not gen_pl:
          return "same"
        nonvowel_stem = re.sub(u"ь$", "", gen_pl)
        # Special handling for e.g. зна́чення gen pl зна́чень
        if vowel_stem == nonvowel_stem or vowel_stem == nonvowel_stem + nonvowel_stem[-1]:
          return "same"
        dereduced_stem = uk.dereduce(vowel_stem, True)
        if dereduced_stem and uk.remove_accents(dereduced_stem) == nonvowel_stem:
          return "reducible"
        elif apply_vowel_alternation(vowel_stem, "i") == nonvowel_stem:
          return "i"
        else:
          pagemsg("WARNING: Unable to determine relationship between nom_sg %s and gen_pl %s" %
            (nom_sg, gen_pl))
          return None
      else:
        nonvowel_stem = re.sub(u"ь$", "", nom_sg)
        vowel_stem = re.sub(u"[аяуюиії]$", "", gen_sg)
        if re.search(uk.vowel_c + "$", vowel_stem):
          vowel_stem += u"й"
        if vowel_stem == nonvowel_stem:
          return "same"
        if uk.reduce(nonvowel_stem) == vowel_stem:
          return "reducible"
        elif apply_vowel_alternation(nonvowel_stem, "io") == vowel_stem:
          return "io"
        elif apply_vowel_alternation(nonvowel_stem, "ie") == vowel_stem:
          return "ie"
        else:
          pagemsg("WARNING: Unable to determine relationship between nom_sg %s and gen_sg %s" %
            (nom_sg, gen_sg))
          return None

    def construct_defaulted_seen_patterns(seen_patterns, lemma, gender, reducible):
      defaulted_seen_patterns = []
      if seen_patterns == ["b", "c"]:
        seen_patterns = ["c", "b"]
      elif seen_patterns == ["b", "d"]:
        seen_patterns = ["d", "b"]
      for pattern in seen_patterns:
        defstress = default_stress(lemma, gender, reducible)
        if defstress == pattern:
          if reducible:
            defaulted_seen_patterns.append("*")
          elif len(seen_patterns) > 1:
            defaulted_seen_patterns.append(pattern)
        elif reducible:
          defaulted_seen_patterns.append(pattern + "*")
        else:
          defaulted_seen_patterns.append(pattern)
      return defaulted_seen_patterns

    if tn == "uk-decl-noun":
      check_multi_stressed(14)
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
      acc_pl = fetch("8")
      acc_pl_end_stressed = param_is_end_stressed(acc_pl)
      ins_pl = fetch("10")
      ins_pl_end_stressed = param_is_end_stressed(ins_pl, instrumental_plural_endings)
      loc_pl = fetch("12")
      loc_pl_end_stressed = param_is_end_stressed(loc_pl)
      if (gen_sg_end_stressed == "unknown" or
          acc_sg_end_stressed == "unknown" or
          voc_sg_end_stressed == "unknown" or
          nom_pl_end_stressed == "unknown" or
          loc_pl_end_stressed == "unknown"):
        pagemsg("WARNING: Missing stresses, can't determine accent pattern: %s" % str(t))
        continue
      seen_patterns = []
      for pattern, accents in stress_patterns:
        if (matches(ins_sg_end_stressed, accents["inssg"]) and
            matches(acc_sg_end_stressed, accents["accsg"]) and
            matches(nom_pl_end_stressed, accents["nompl"]) and
            matches(loc_pl_end_stressed, accents["locpl"])):
          seen_patterns.append(pattern)
      if "a" in seen_patterns and "b" in seen_patterns:
        # If a and b apply, most others can apply as well
        seen_patterns = ["a", "b"]
      elif "a" in seen_patterns and "c" in seen_patterns:
        # If a and c apply, e can apply as well
        seen_patterns = ["a", "c"]
      elif "a" in seen_patterns and "d" in seen_patterns:
        # If a and d apply, d' can apply as well
        seen_patterns = ["a", "d"]
      elif "b" in seen_patterns and "d" in seen_patterns:
        # If b and d apply, f can apply as well
        seen_patterns = ["b", "d"]
      gen_sg_endings = fetch_endings("3", genitive_singular_endings)
      dat_sg_endings = fetch_endings("5", dative_singular_endings)
      ins_sg_endings = fetch_endings("9", instrumental_singular_endings)
      loc_sg_endings = fetch_endings("11", locative_singular_endings)
      voc_sg_endings = fetch_endings("13", vocative_singular_endings)
      nom_pl_endings = fetch_endings("2", nominative_plural_endings)
      gen_pl_endings = fetch_endings("4", genitive_plural_endings)

      if not heads:
        pagemsg("WARNING: No head found")
        heads = [pagetitle]
      pagemsg("%s\tgender:%s\tanimacy:%s\taccent:%s\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tvoc_sg:%s\tgen_pl:%s\tnumber:both\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tvoc_sg:%s\tnom_pl:%s\tgen_pl:%s\t| %s || \"?\" || %s || %s || %s || %s || %s || %s || %s|| " % (
        "/".join(heads), gender, animacy, ":".join(seen_patterns),
        stress(gen_sg_end_stressed), stress(dat_sg_end_stressed),
        stress(loc_sg_end_stressed), stress(voc_sg_end_stressed),
        stress(gen_pl_end_stressed),
        gen_sg_endings, dat_sg_endings, loc_sg_endings, voc_sg_endings,
        nom_pl_endings, gen_pl_endings, canon(nom_sg), canon(gen_sg),
        canon(loc_sg), canon(voc_sg), canon(nom_pl), canon(gen_pl),
        canon(ins_pl), ins_sg_note(ins_sg)))
      if len(heads) > 1:
        pagemsg("WARNING: Multiple heads, not inferring declension: %s" % ",".join(heads))
        continue
      if gender == "unknown" or animacy == "unknown":
        pagemsg("WARNING: Unknown gender or animacy, not inferring declension")
        continue
      defan = infer_animacy(nom_pl, gen_pl, acc_pl)
      if defan != animacy:
        pagemsg("WARNING: Inferred animacy %s != explicit animacy %s, not inferring declension" %
            (defan, animacy))
        continue
      lemma = heads[0]
      parts = []
      defg = infer_gender(lemma)
      if gender != defg:
        parts.append(gender)
      alternation = infer_alternations(nom_sg, gen_sg, gen_pl)
      reducible = alternation == "reducible"
      defaulted_seen_patterns = construct_defaulted_seen_patterns(seen_patterns, lemma, gender, reducible)
      if defaulted_seen_patterns:
        parts.append(",".join(defaulted_seen_patterns))
      if animacy != "in":
        parts.append(animacy)
      if alternation in ["i", "ie", "io"]:
        parts.append(alternation)
      if gender == "M":
        if re.search(u"у́?$", gen_sg):
          parts.append("genu")
        elif re.search(u"ю́?$", gen_sg):
          parts.append("genju")
      pagemsg("Inferred declension %s<%s>" % (lemma, ".".join(parts)))

    elif tn == "uk-decl-noun-unc":
      check_multi_stressed(7)
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
        pagemsg("WARNING: Missing stresses, can't determine accent pattern: %s" % str(t))
        continue
      if not heads:
        pagemsg("WARNING: No head found")
        heads = [pagetitle]
      lemma = heads[0]
      seen_patterns = []
      for pattern, accents in stress_patterns:
        if pattern not in ["a", "d" if re.search(u"[аяео]́?$", lemma) else "b", "d'"]:
          continue
        if (matches(ins_sg_end_stressed, accents["inssg"]) and
            matches(acc_sg_end_stressed, accents["accsg"])):
          seen_patterns.append(pattern)
      if "a" in seen_patterns and "b" in seen_patterns:
        seen_patterns = ["a", "b"]
      if "a" in seen_patterns and "d" in seen_patterns:
        seen_patterns = ["a", "d"]
      gen_sg_endings = fetch_endings("2", genitive_singular_endings)
      dat_sg_endings = fetch_endings("3", dative_singular_endings)
      ins_sg_endings = fetch_endings("5", instrumental_singular_endings)
      loc_sg_endings = fetch_endings("6", locative_singular_endings)
      voc_sg_endings = fetch_endings("7", vocative_singular_endings)

      pagemsg("%s\tgender:%s\tanimacy:%s\taccent:%s\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tvoc_sg:%s\tgen_pl:-\tnumber:sg\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tvoc_sg:%s\tnom_pl:-\tgen_pl:-\t| %s || \"?\" || %s || %s || %s || - || - || - || %s|| " % (
        "/".join(heads), gender, animacy, ":".join(seen_patterns),
        stress(gen_sg_end_stressed), stress(dat_sg_end_stressed),
        stress(loc_sg_end_stressed), stress(voc_sg_end_stressed),
        gen_sg_endings, dat_sg_endings, loc_sg_endings, voc_sg_endings,
        canon(nom_sg), canon(gen_sg), canon(loc_sg), canon(voc_sg), ins_sg_note(ins_sg)))

      if len(heads) > 1:
        pagemsg("WARNING: Multiple heads, not inferring declension: %s" % ",".join(heads))
        continue
      if gender == "unknown" or animacy == "unknown":
        pagemsg("WARNING: Unknown gender or animacy, not inferring declension")
        continue
      parts = []
      defg = infer_gender(lemma)
      if gender != defg:
        parts.append(gender)
      alternation = infer_alternations(nom_sg, gen_sg, None)
      reducible = alternation == "reducible"
      defaulted_seen_patterns = construct_defaulted_seen_patterns(seen_patterns, lemma, gender, reducible)
      if defaulted_seen_patterns:
        parts.append(",".join(defaulted_seen_patterns))
      if animacy != "in":
        parts.append(animacy)
      parts.append("sg")
      if alternation in ["i", "ie", "io"]:
        parts.append(alternation)
      if gender == "M" and re.search("^" + uk.uppercase_c, lemma):
        if re.search(u"у́?$", gen_sg):
          parts.append("genu")
        elif re.search(u"ю́?$", gen_sg):
          parts.append("genju")
      pagemsg("Inferred declension %s<%s>" % (lemma, ".".join(parts)))

    elif tn == "uk-decl-noun-pl":
      check_multi_stressed(7)
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
        pagemsg("WARNING: Missing stresses, can't determine accent pattern: %s" % str(t))
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

      if not heads:
        pagemsg("WARNING: No head found")
        heads = [pagetitle]
      pagemsg("%s\tgender:%s\tanimacy:%s\taccent:%s\tgen_sg:-\tdat_sg:-\tloc_sg:-\tvoc_sg:-\tgen_pl:%s\tnumber:pl\tgen_sg:-\tdat_sg:-\tloc_sg:-\tvoc_sg:-\tnom_pl:%s\tgen_pl:%s\t| %s || \"?\" || - || - || - || %s || %s || %s || || " % (
        "/".join(heads), gender, animacy, ":".join(seen_patterns),
        stress(gen_pl_end_stressed),
        nom_pl_endings, gen_pl_endings,
        canon(nom_pl), canon(nom_pl), canon(gen_pl), canon(ins_pl)))


parser = blib.create_argparser("Analyze Ukrainian noun declensions",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_cats=["Ukrainian nouns"], stdin=True)
