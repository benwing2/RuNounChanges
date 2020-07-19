#!/usr/bin/env python
#coding: utf-8

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import belib as be

import find_regex

AC = u"\u0301"

possible_vowel_alternations = ["ae", "ao"]#, "yo"

def param_is_end_accented(param, possible_endings=[]):
  # add_monosyllabic_accent already called
  values = re.split(", *", param)
  if any(not be.is_accented(v) for v in values):
    return "unknown"
  if any(be.is_mixed_accented(v, possible_endings) for v in values):
    return "mixed"
  end_accents = [be.is_end_accented(v, possible_endings) for v in values]
  if all(end_accents):
    return True
  if any(end_accents):
    return "mixed"
  return False

def is_undefined(word):
  return word in ["", "-", u"-", u"—"]

accent_patterns = [
  ("a", {"inssg": False, "accsg": None, "nompl": False, "locpl": False}),
  ("b", {"inssg": True, "accsg": True, "nompl": True, "locpl": True}),
  ("c", {"inssg": False, "accsg": None, "nompl": True, "locpl": True}),
  ("d", {"inssg": True, "accsg": True, "nompl": False, "locpl": False}),
  ("d'", {"inssg": True, "accsg": False, "nompl": False, "locpl": False}),
  ("e", {"inssg": False, "accsg": None, "nompl": False, "locpl": True}),
  ("f", {"inssg": True, "accsg": True, "nompl": False, "locpl": True}),
  ("f'", {"inssg": True, "accsg": False, "nompl": False, "locpl": True}),
]

genitive_singular_endings = [u"а", u"я", u"у", u"ю", u"і", u"ы"]
dative_singular_endings = [u"у", u"ю", u"е", u"э", u"і", u"ы"]
instrumental_singular_endings = [u"ом", u"ам", u"ем", u"эм", u"ём", u"ям", u"ой", u"ою", u"ай", u"аю", u"яй", u"яю", u"ёй", u"ёю", u"ей", u"ею", u"эй", u"эю", u"у", u"ю"]
locative_singular_endings = [u"у", u"ю", u"е", u"э", u"і", u"ы"]
nominative_plural_endings = [u"і", u"ы", u"а", u"я", u"е", u"э"]
genitive_plural_endings = [u"ей", u"эй", u"ёй", u"оў", u"аў", u"ёў", u"яў", u"ь", ""]
instrumental_plural_endings = [u"амі", u"ямі", u"ьмі"]

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
    if tn in ["be-noun", "be-proper noun"]:
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
        v = be.mark_stressed_vowels_in_unstressed_syllables(v, pagemsg)
        retval.append(be.add_monosyllabic_accent(v))
      return ", ".join(retval)

    def matches(is_end_stressed, should_be_end_stressed):
      return (is_end_stressed == "mixed" or should_be_end_stressed is None or
          is_end_stressed == should_be_end_stressed)

    def fetch_endings(param, endings):
      paramval = fetch(param)
      values = re.split(", *", paramval)
      found_endings = []
      for v in values:
        v = v.replace(be.AC, "")
        for ending in endings:
          if v.endswith(ending):
            found_endings.append(ending)
            break
        else: # no break
          pagemsg("WARNING: Couldn't recognize ending for %s=%s: %s" % (
            param, paramval, unicode(t)))
      return ":".join(found_endings)

    def canon(val):
      values = re.split(", *", val)
      return "/".join(be.undo_mark_stressed_vowels_in_unstressed_syllables(v) for v in values)
    def stress(endstressed):
      return (
        "endstressed" if endstressed == True else
        "stemstressed" if endstressed == False else "mixed"
      )
    def check_multi_stressed(maxparam):
      for i in xrange(1, maxparam + 1):
        val = getparam(t, str(i))
        vals = re.split(r",\s*", val)
        for v in vals:
          if be.is_multi_stressed(v):
            pagemsg("WARNING: Param %s=%s has multiple stresses: %s" % (
              (str(i), val, unicode(t))))
          if be.needs_accents(v):
            pagemsg("WARNING: Param %s=%s has missing stress: %s" % (
              (str(i), val, unicode(t))))
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
        return "an"
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
      elif re.search(be.cons_c + "$", lemma):
        return "M"
      else:
        pagemsg("WARNING: Unrecognized lemma ending: %s" % lemma)
        return None

    def default_stress(lemma, gender, reducible):
      if re.search(u"я́$", lemma) and gender == "N":
        return "b"
      elif re.search(AC + "$", lemma):
        return "d"
      elif reducible and re.search(u"[еоєі]́" + be.cons_c + u"ь?$", lemma):
        return "b"
      else:
        return "a"

    def destress_after_stress(vowel):
       return vowel.replace(AC, "").replace(u"ё", u"е").replace(u"о", u"а").replace(u"э", u"а")

    def apply_vowel_alternation(stem, valt):
      if valt == "ae":
        ae_alternation = {
          u"а": u"э́",
          u"А": u"Э́",
          u"я": u"е́",
          u"Я": u"Е́",
        }
        modstem = re.sub(u"^(.*)([аАяЯ])(" + be.cons_c + "*(?:" + be.vowel_c + AC + u"|ё)" + be.cons_c + "*)$",
          lambda m: m.group(1) + ae_alternation[m.group(2)] + destress_after_stress(m.group(3)),
          stem
        )
      elif valt == "ao":
        ao_alternation = {
          u"а": u"о́",
          u"А": u"О́",
          u"я": u"ё",
          u"Я": u"Ё",
        }
        modstem = re.sub(u"^(.*)([аАяЯ])(" + be.cons_c + "*(?:" + be.vowel_c + AC + "|ё)" + be.cons_c + "*)$",
          lambda m: m.group(1) + ao_alternation[m.group(2)] + destress_after_stress(m.group(3)),
          stem
        )
      elif valt == "yo":
        yo_alternation = {
          u"ы": u"о́",
          u"Ы": u"О́",
        }
        modstem = re.sub(u"^(.*)([ыЫ])(" + be.cons_c + "*(?:" + be.vowel_c + AC + "|ё)" + be.cons_c + "*)$",
          lambda m: m.group(1) + yo_alternation[m.group(2)] + destress_after_stress(m.group(3)),
          stem
        )
      else:
        assert False
      if modstem == stem:
        return None
      return modstem

    def infer_alternations(nom_sg, nom_pl):
      nom_sg = truncate_extra_forms(nom_sg)
      nom_pl = truncate_extra_forms(nom_pl)
      if re.search(u"^.*[аяеёо]́$", nom_sg):
        m = re.search(u"^(.*)[ыіая]$", nom_pl)
        if m:
          pl_stem = m.group(1)
          for valt in possible_vowel_alternations:
            valt_nom_sg = be.apply_vowel_alternation(nom_sg, valt)
            if valt_nom_sg:
              valt_nom_sg = re.sub(u"[аяеёо]́$", "", valt_nom_sg)
              valt_nom_sg = be.maybe_accent_final_syllable(valt_nom_sg)
              valt_nom_sg = be.destress_vowels_after_stress_movement(valt_nom_sg)
              if valt_nom_sg == be.undo_mark_stressed_vowels_in_unstressed_syllables(pl_stem):
                return valt
      m = re.search(u"^(.*" + be.cons_c + u")ь?$", nom_sg)
      if m:
        nom_sg = m.group(1)
        nom_sg = re.sub(u"й$", "", nom_sg)
        if re.search(u"я" + be.cons_c + "*" + be.vowel_c + AC + be.cons_c + "*$", nom_sg):
          nom_sg = be.apply_vowel_alternation(nom_sg, "ae")
          m = re.search(u"^.*([ыіая]́)$", nom_pl)
          if m:
            nom_sg = be.remove_accents(nom_sg) + m.group(1)
            nom_sg = be.destress_vowels_after_stress_movement(nom_sg)
            if nom_sg == be.undo_mark_stressed_vowels_in_unstressed_syllables(nom_pl):
              return "ae"
      return None

    def infer_reducible(nom_sg, gen_sg, gen_pl):
      nom_sg = truncate_extra_forms(nom_sg)
      gen_sg = truncate_extra_forms(gen_sg)
      gen_pl = gen_pl and truncate_extra_forms(gen_pl)
      m = re.search(u"^(.*)[аяеоё](" + AC + "?)$", nom_sg)
      if m:
        vowel_stem = m.group(1)
        epenthetic_stress = m.group(2) == AC
        if re.search(be.vowel_c + AC + "?$", vowel_stem):
          vowel_stem += u"й"
        if not gen_pl:
          return "same"
        nonvowel_stem = re.sub(u"ў$", u"в", re.sub(u"ь$", "", gen_pl))
        # Special handling for e.g. зна́чення gen pl зна́чень
        if (be.remove_accents(vowel_stem) == be.remove_accents(nonvowel_stem) or
            be.remove_accents(vowel_stem) == be.remove_accents(nonvowel_stem) + nonvowel_stem[-1]):
          return "same"
        if be.dereduce(vowel_stem, epenthetic_stress) == nonvowel_stem:
          return "reducible"
        elif (be.remove_accents(vowel_stem) + u"ав" == be.remove_accents(nonvowel_stem) or
            be.remove_accents(vowel_stem) + u"яв" == be.remove_accents(nonvowel_stem)):
          return "au"
        elif be.apply_vowel_alternation(vowel_stem, "ae") == nonvowel_stem:
          return "ae"
        elif be.apply_vowel_alternation(vowel_stem, "ao") == nonvowel_stem:
          return "ao"
        elif be.apply_vowel_alternation(vowel_stem, "yo") == nonvowel_stem:
          return "yo"
        else:
          pagemsg("WARNING: Unable to determine relationship between nom_sg %s and gen_pl %s" %
            (nom_sg, gen_pl))
          return None
      else:
        nonvowel_stem = re.sub(u"ь$", "", nom_sg)
        vowel_stem = re.sub(u"в$", u"ў", re.sub(u"[аяуюыі]́?$", "", gen_sg))
        if re.search(be.vowel_c + AC + "?$", vowel_stem):
          vowel_stem += u"й"
        if be.remove_accents(vowel_stem) == be.remove_accents(nonvowel_stem):
          return "same"
        if be.reduce(nonvowel_stem) == vowel_stem:
          return "reducible"
        elif be.apply_vowel_alternation(vowel_stem, "ae") == nonvowel_stem:
          return "ae"
        elif be.apply_vowel_alternation(vowel_stem, "ao") == nonvowel_stem:
          return "ao"
        elif be.apply_vowel_alternation(vowel_stem, "yo") == nonvowel_stem:
          return "yo"
        else:
          pagemsg("WARNING: Unable to determine relationship between nom_sg %s and gen_sg %s" %
            (nom_sg, gen_sg))
          return None

    def construct_defaulted_seen_patterns(seen_patterns, lemma, gender, reducible, au):
      defaulted_seen_patterns = []
      if seen_patterns == ["b", "c"]:
        seen_patterns = ["c", "b"]
      elif seen_patterns == ["b", "d"]:
        seen_patterns = ["d", "b"]
      au = au and u"(ў)" or ""
      reducible = reducible and "*" or ""
      for pattern in seen_patterns:
        defstress = default_stress(lemma, gender, reducible)
        if defstress == pattern:
          if reducible or au:
            defaulted_seen_patterns.append(reducible + au)
          elif len(seen_patterns) > 1:
            defaulted_seen_patterns.append(pattern)
        else:
          defaulted_seen_patterns.append(pattern + reducible + au)
      return defaulted_seen_patterns

    if tn == "be-decl-noun":
      check_multi_stressed(14)
      nom_sg = fetch("1")
      gen_sg = fetch("3")
      gen_sg_end_stressed = param_is_end_accented(gen_sg)
      dat_sg = fetch("5")
      dat_sg_end_stressed = param_is_end_accented(dat_sg, dative_singular_endings)
      acc_sg = fetch("7")
      acc_sg_end_stressed = param_is_end_accented(acc_sg)
      ins_sg = fetch("9")
      ins_sg_end_stressed = param_is_end_accented(ins_sg, instrumental_singular_endings)
      loc_sg = fetch("11")
      loc_sg_end_stressed = param_is_end_accented(loc_sg, locative_singular_endings)
      nom_pl = fetch("2")
      nom_pl_end_stressed = param_is_end_accented(nom_pl)
      gen_pl = fetch("4")
      gen_pl_end_stressed = param_is_end_accented(gen_pl)
      acc_pl = fetch("8")
      acc_pl_end_stressed = param_is_end_accented(acc_pl)
      ins_pl = fetch("10")
      ins_pl_end_stressed = param_is_end_accented(ins_pl, instrumental_plural_endings)
      loc_pl = fetch("12")
      loc_pl_end_stressed = param_is_end_accented(loc_pl)
      if (gen_sg_end_stressed == "unknown" or
          acc_sg_end_stressed == "unknown" or
          nom_pl_end_stressed == "unknown" or
          loc_pl_end_stressed == "unknown"):
        pagemsg("WARNING: Missing stresses, can't determine accent pattern: %s" % unicode(t))
        continue
      seen_patterns = []
      for pattern, accents in accent_patterns:
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
      nom_pl_endings = fetch_endings("2", nominative_plural_endings)
      gen_pl_endings = fetch_endings("4", genitive_plural_endings)

      if not heads:
        pagemsg("WARNING: No head found")
        heads = [pagetitle]
      pagemsg("%s\tgender:%s\tanimacy:%s\taccent:%s\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tgen_pl:%s\tnumber:both\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tnom_pl:%s\tgen_pl:%s\t| %s || \"?\" || %s || %s || %s || %s || %s || %s|| " % (
        "/".join(heads), gender, animacy, ":".join(seen_patterns),
        stress(gen_sg_end_stressed), stress(dat_sg_end_stressed),
        stress(loc_sg_end_stressed), stress(gen_pl_end_stressed),
        gen_sg_endings, dat_sg_endings, loc_sg_endings,
        nom_pl_endings, gen_pl_endings, canon(nom_sg), canon(gen_sg),
        canon(loc_sg), canon(nom_pl), canon(gen_pl),
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
      alternation = infer_alternations(nom_sg, nom_pl)
      result = infer_reducible(nom_sg, gen_sg, gen_pl)
      reducible = result == "reducible"
      au = result == "au"
      defaulted_seen_patterns = construct_defaulted_seen_patterns(seen_patterns, lemma, gender, reducible, au)
      if defaulted_seen_patterns:
        parts.append(",".join(defaulted_seen_patterns))
      if animacy != "in":
        parts.append(animacy)
      if alternation in ["ae", "ao", "yo"]:
        parts.append(alternation)
      if gender == "M":
        if re.search(u"у́?$", gen_sg):
          parts.append("genu")
        elif re.search(u"ю́?$", gen_sg):
          parts.append("genju")
      pagemsg("Inferred declension %s<%s>" % (lemma, ".".join(parts)))

    elif tn == "be-decl-noun-unc":
      check_multi_stressed(7)
      nom_sg = fetch("1")
      gen_sg = fetch("2")
      gen_sg_end_stressed = param_is_end_accented(gen_sg)
      dat_sg = fetch("3")
      dat_sg_end_stressed = param_is_end_accented(dat_sg, dative_singular_endings)
      acc_sg = fetch("4")
      acc_sg_end_stressed = param_is_end_accented(acc_sg)
      ins_sg = fetch("5")
      ins_sg_end_stressed = param_is_end_accented(ins_sg, instrumental_singular_endings)
      loc_sg = fetch("6")
      loc_sg_end_stressed = param_is_end_accented(loc_sg, locative_singular_endings)
      if (gen_sg_end_stressed == "unknown" or
          acc_sg_end_stressed == "unknown"):
        pagemsg("WARNING: Missing stresses, can't determine accent pattern: %s" % unicode(t))
        continue
      if not heads:
        pagemsg("WARNING: No head found")
        heads = [pagetitle]
      lemma = heads[0]
      seen_patterns = []
      for pattern, accents in accent_patterns:
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

      pagemsg("%s\tgender:%s\tanimacy:%s\taccent:%s\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tgen_pl:-\tnumber:sg\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tnom_pl:-\tgen_pl:-\t| %s || \"?\" || %s || %s || - || - || - || %s|| " % (
        "/".join(heads), gender, animacy, ":".join(seen_patterns),
        stress(gen_sg_end_stressed), stress(dat_sg_end_stressed),
        stress(loc_sg_end_stressed),
        gen_sg_endings, dat_sg_endings, loc_sg_endings,
        canon(nom_sg), canon(gen_sg), canon(loc_sg), ins_sg_note(ins_sg)))

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
      result = infer_reducible(nom_sg, gen_sg, None)
      reducible = result == "reducible"
      assert result != "au"
      defaulted_seen_patterns = construct_defaulted_seen_patterns(seen_patterns, lemma, gender, reducible, False)
      if defaulted_seen_patterns:
        parts.append(",".join(defaulted_seen_patterns))
      if animacy != "in":
        parts.append(animacy)
      parts.append("sg")
      if gender == "M" and re.search("^" + be.uppercase_c, lemma):
        if re.search(u"у́?$", gen_sg):
          parts.append("genu")
        elif re.search(u"ю́?$", gen_sg):
          parts.append("genju")
      pagemsg("Inferred declension %s<%s>" % (lemma, ".".join(parts)))

    elif tn == "be-decl-noun-pl":
      check_multi_stressed(7)
      nom_pl = fetch("1")
      nom_pl_end_stressed = param_is_end_accented(nom_pl)
      gen_pl = fetch("2")
      gen_pl_end_stressed = param_is_end_accented(gen_pl)
      ins_pl = fetch("5")
      ins_pl_end_stressed = param_is_end_accented(ins_pl, instrumental_plural_endings)
      loc_pl = fetch("6")
      loc_pl_end_stressed = param_is_end_accented(loc_pl)
      if (nom_pl_end_stressed == "unknown" or
          loc_pl_end_stressed == "unknown"):
        pagemsg("WARNING: Missing stresses, can't determine accent pattern: %s" % unicode(t))
        continue
      seen_patterns = []
      for pattern, accents in accent_patterns:
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
      pagemsg("%s\tgender:%s\tanimacy:%s\taccent:%s\tgen_sg:-\tdat_sg:-\tloc_sg:-\tgen_pl:%s\tnumber:pl\tgen_sg:-\tdat_sg:-\tloc_sg:-\tnom_pl:%s\tgen_pl:%s\t| %s || \"?\" || - || - || %s || %s || %s || || " % (
        "/".join(heads), gender, animacy, ":".join(seen_patterns),
        stress(gen_pl_end_stressed),
        nom_pl_endings, gen_pl_endings,
        canon(nom_pl), canon(nom_pl), canon(gen_pl), canon(ins_pl)))


def process_page(page, index):
  pagetitle = unicode(page.title())
  process_text_on_page(index, pagetitle, page.text)


parser = blib.create_argparser("Analyze Belarusian noun declensions",
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
      default_cats=["Belarusian nouns"])
