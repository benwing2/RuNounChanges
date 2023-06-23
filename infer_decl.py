#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# FIXME:
#
# 1. With plural-only lemmas, leave as plural instead of converting to
#    singular. (DONE)
# 2. With manual bareval, set gen_pl or nom_sg override (e.g. in
#    варёное яйцо́).
# 3. Use Z-style stress patterns. (DONE)
# 4. Don't need to specify +short with -ов, same for +mixed.
# 5. Check that recognize-plural code deals correctly with short plural
#    adjectives like in Соломо́новы острова́. (IT APPEARS TO.)
# 6. Recognize unusual genitive plural and add (2).

import re, argparse
import traceback, sys
import pywikibot
import mwparserfromhell
import blib
from blib import rmparam, getparam, msg, site

from rulib import *

verbose = True
mockup = False
# Uncomment the following line to enable test mode
#mockup = True
# If true, use the old ru-noun-table template, instead of new
# ru-decl-noun-new
old_template = True

if old_template:
  decl_template = "ru-noun-table"
else:
  decl_template = "ru-decl-noun-m"

ru_decl_noun_cases = [
  "nom_sg", "nom_pl", "gen_sg", "gen_pl", "dat_sg", "dat_pl",
  "acc_sg", "acc_pl", "ins_sg", "ins_pl", "pre_sg", "pre_pl",
  "loc", None, "voc"]
ru_decl_noun_unc_cases = [
  "nom_sg", "gen_sg", "dat_sg", "acc_sg", "ins_sg", "pre_sg",
  "loc", "voc"]
ru_decl_noun_pl_cases = [
  "nom_pl", "gen_pl", "dat_pl", "acc_pl", "ins_pl", "pre_pl",
  ]
all_cases = [x for x in ru_decl_noun_cases] + ["par"]

all_stress_patterns = ["a", "b", "c", "d", "e", "f", "d'", "f'"]
matching_stress_patterns = {}
matching_stress_patterns["stem"] = {}
matching_stress_patterns["ending"] = {}
matching_stress_patterns["none"] = {}
matching_stress_patterns["stem"]["stem"] = {"by":"pre_pl", "stem":"a", "ending":"e"}
matching_stress_patterns["stem"]["ending"] = ["c"]
matching_stress_patterns["ending"]["stem"] = {
  "by":"pre_pl",
  "stem":{"by":"acc_sg", "ending":"d", "stem":"d'"},
  "ending":{"by":"acc_sg", "ending":"f", "stem":"f'"},
}
matching_stress_patterns["ending"]["ending"] = ["b"]
matching_stress_patterns["stem"]["none"] = ["a"]
matching_stress_patterns["ending"]["none"] = {"by":"acc_sg", "ending":"b", "stem":"f'"}
matching_stress_patterns["none"]["stem"] = {"by":"pre_pl", "stem":"a", "ending":"e"}
matching_stress_patterns["none"]["ending"] = ["b"]

manual_templates = ["ru-decl-noun", "ru-decl-noun-unc", "ru-decl-noun-pl"]

def compare_terms(case, real, pred, pagemsg):
  if real == pred:
    return True
  realwords = re.split("([ -]+)", real)
  predwords = re.split("([ -]+)", pred)
  if len(realwords) != len(predwords):
    return False
  for realword, predword in zip(realwords, predwords):
    if realword == predword:
      pass
    elif is_unstressed(realword) and make_unstressed_once_ru(predword) == realword:
      pagemsg("For case %s, real word %s in %s missing an accent that's present in predicted word %s in %s; allowed" %
          (case, realword, real, predword, pred))
    else:
      return False
  return True

def remove_duplicates(form):
  forms = re.split(r"\s*,\s*", form)
  new_forms = []
  for f in forms:
    if f not in new_forms:
      new_forms.append(f)
  return ",".join(new_forms)

def trymatch(forms, args, pagemsg, multiword=False):
  if mockup:
    ok = True
  else:
    tempcall = "{{ru-generate-noun-forms|" + "|".join(args) + "}}"
    result = site.expand_text(tempcall)
    if verbose:
      pagemsg("%s = %s" % (tempcall, result))
    if result.startswith('<strong class="error">'):
      result = re.sub("<.*?>", "", result)
      pagemsg("ERROR: %s" % result)
      return False
    pred_forms = {}
    for formspec in re.split(r"\|", result):
      case, value = re.split(r"=", formspec, 1)
      pred_forms[case] = value
    ok = True
    for case in all_cases:
      pred_form = pred_forms.get(case, "")
      real_form = forms.get(case, "")
      if pred_form and not real_form:
        pagemsg("Missing actual form for case %s (predicted %s)" % (case, pred_form))
        ok = False
      elif real_form and not pred_form:
        pagemsg("Actual has extra form %s=%s not in predicted" % (case, real_form))
        ok = False
      elif not compare_terms(case, real_form, pred_form, pagemsg):
        if compare_terms(case, real_form, re.sub("//.*$", "", pred_form), pagemsg):
          # Happens esp. in the gen sg of adjectival nominals
          pagemsg("For case %s, predicted %s has manual translit and actual %s doesn't; allowed" % (case, pred_form, real_form))
        elif (case == "ins_sg" and "," in pred_form and
            compare_terms(case, real_form, re.sub(",.*$", "", pred_form), pagemsg)):
          pagemsg("For case ins_sg, predicted form %s has an alternate form not in actual form %s; allowed" % (pred_form, real_form))
        elif "," in real_form and compare_terms(case, remove_duplicates(real_form), pred_form, pagemsg):
          pagemsg("For case %s, actual %s same as predicted %s but for duplicate words; allowed" % (case, real_form, pred_form))
        else:
          pagemsg("For case %s, actual %s differs from predicted %s" % (case,
            real_form, pred_form))
          ok = False
  if ok:
    pagemsg("Found a %smatch: {{%s|%s}}" % (multiword and "multiword " or "",
      decl_template, "|".join(args)))
  return ok

def synthesize_singular(nompl, prepl, gender, pagemsg):
  m = re.search(r"^(.*)([ыи])(́?)е$", nompl)
  if m:
    stem = m.group(1)
    ty = (re.search("[кгx]$", stem) and "velar" or
          re.search("[шщжч]$", stem) and "sibilant" or
          re.search("ц$", stem) and "c" or
          m.group(2) == "и" and "soft" or
          "hard")
    ac = m.group(3)
    if ac:
      sg = (stem + "о́й" if gender == "m" else
          stem + "а́я" if gender == "f" else stem + "о́е")
    elif ty == "soft":
      sg = (stem + "ий" if gender == "m" else
          stem + "яя" if gender == "f" else stem + "ее")
    elif ty == "velar" or ty == "sibilant":
      sg = (stem + "ий" if gender == "m" else
          stem + "ая" if gender == "f" else stem + "ое")
    elif ty == "c":
      sg = (stem + "ый" if gender == "m" else
          stem + "ая" if gender == "f" else stem + "ее")
    else:
      sg = (stem + "ый" if gender == "m" else
          stem + "ая" if gender == "f" else stem + "ое")
    return [sg]

  m = re.search(r"^(.*)[аяыи]́?$", nompl)
  if not m:
    pagemsg("WARNING: Strange nom plural %s" % nompl)
    return []
  stem = try_to_stress(m.group(1))
  soft = re.search(r"яхъ?$", prepl)
  if soft and gender == "f":
    return [add_soft_sign(stem), stem + "я"]
  return [stem + "а" if gender == "f" else
          add_soft_sign(stem) if soft and gender == "m" else
          stem if gender == "m" else
          stem + "е" if soft and gender == "n" else
          add_hard_neuter(stem) if gender == "n" else
          do_assert(False, "Unrecognized gender: %s" % gender)]

def separate_multiwords(forms, splitre):
  words = []
  for case in forms:
    for multiform in re.split(r"\s*,\s*", forms[case]):
      formwords = re.split(splitre, multiform)
      while len(words) < len(formwords):
        words.append({})
      i = 0
      for word in formwords:
        if case in words[i]:
          words[i][case] += "," + word
        else:
          words[i][case] = word
        i += 1
  # Remove duplicates from individual words (e.g. if overall form was
  # бри́твой О́ккама,бри́твою О́ккама)
  for i in range(len(words)):
    for case in words[i]:
      words[i][case] = remove_duplicates(words[i][case])
  return words

def arg1_is_stress(arg1):
  if not arg1:
    return False
  for arg in re.split(",", arg1):
    if not (re.search("^[a-f]'?'?$", arg) or re.search(r"^[1-6]\*?$", arg)):
      return False
  return True

def infer_decl(t, noungender, linked_headwords, pagemsg):
  if verbose:
    pagemsg("Processing %s" % str(t))

  tname = str(t.name).strip()
  forms = {}

  # Initialize all cases to blank in case we don't set them again later
  for case in ru_decl_noun_cases:
    if case:
      forms[case] = ""

  if tname == "ru-decl-noun":
    number = []
    numonly = ""
    getcases = ru_decl_noun_cases
  elif tname == "ru-decl-noun-unc":
    number = ["n=sg"]
    numonly = "sg"
    getcases = ru_decl_noun_unc_cases
  elif tname == "ru-decl-noun-pl":
    number = []
    numonly = "pl"
    getcases = ru_decl_noun_pl_cases
  else:
    assert False, "Unrecognized template name: %s" % tname

  i = 1
  for case in getcases:
    if case:
      form = getparam(t, i).strip()
      form = blib.remove_links(form)
      if case == "pre_sg" or case == "pre_pl":
        # eliminate leading preposition
        form = re.sub(r"^о(б|бо)?\s+", "", form)
      # eliminate <br />, typically separating alternants
      form = re.sub(r"\s*<br\s*/>\s*", "", form)
      # eliminate spaces around commas
      form = re.sub(r"\s*,\s*", ",", form)
      # eliminate stress mark on ё
      form = re.sub(r"ё́", "ё", form)
      if "," in form:
        pagemsg("WARNING: Comma in form, may not handle correctly: %s=%s" %
            (case, form))
      forms[case] = form
    i += 1

  lemma = forms["nom_pl"] if numonly == "pl" else forms["nom_sg"]

  def try_multiword(ty):
    if ty in ["space", "dash"]:
      if (ty == "space" and " " or "-") in lemma:
        words = separate_multiwords(forms, (ty == "space" and r"\s+" or "-"))
        argses = []
        wordno = 0
        for wordforms in words:
          wordno += 1
          pagemsg("Inferring word #%s: %s" % (wordno, wordforms.get("nom_pl", "(blank)") if numonly == "pl" else wordforms.get("nom_sg", "(blank)")))
          args = infer_word(wordforms, noungender, linked_headwords, number, numonly, True, pagemsg)
          if not args:
            pagemsg("Unable to infer word #%s: %s" % (wordno, str(t)))
            return None
          # If we have a gen_pl override, it needs to be for a specific word
          numbered_args = [re.sub("^gen_pl=", "gen_pl%s=" % wordno, arg) for arg in args]
          argses.append(numbered_args)
        animacies = [x for args in argses for x in args if x in ["a=in", "a=an"]]
        if "a=in" in animacies and "a=an" in animacies:
          pagemsg("WARNING: Conflicting animacies in multi-word expression: %s" %
              str(t))
          # FIXME, handle this better
          return None
        animacy = [animacies[0]] if animacies else []
        if animacy == ["a=in"]:
          animacy = []
        # FIXME, eventually we want to do something similar for number in case
        # there are mismatched numbers. For now we always assume the same
        # number restriction for all words (same as passed in, based on the
        # manual template name).
        allargs = []
        for args in argses:
          filterargs = [x for x in args if not re.search("^[an]=", x)]
          if allargs:
            if ty == "dash":
              allargs.append("-")
            elif old_template:
              allargs.append("_")
          allargs.extend(filterargs)
        allargs += animacy + number
        if trymatch(forms, allargs, pagemsg, multiword=True):
          return allargs
        else:
          return None
    else:
      args = infer_word(forms, noungender, {}, number, numonly, False, pagemsg)
      if not args:
        pagemsg("Unable to infer word: %s" % str(t))
        return None
      return [x for x in args if x != "a=in"]
  for ty in ["space", "dash", "single"]:
    args = try_multiword(ty)
    if args:
      return args

def default_stress(lemma, stress, pagemsg):
  if re.search("[ё́]$", lemma):
    defstress = "b"
  else:
    defstress = "a"
  if defstress == stress:
    stress = ""

  return stress

def generate_template_args(stress, lemma, linked_lemma, declspec, plstem, pagemsg):
  stress = default_stress(lemma, stress, pagemsg)
  if old_template:
    args = [stress, linked_lemma, declspec, "", plstem]
    if not args[0]:
      del args[0]
    if not args[-1]:
      del args[-1]
    if not args[-1]:
      del args[-1]
    if not args[-1]:
      del args[-1]
  else:
    declspec = declspec and "^" + declspec or ""
    linked_lemma = linked_lemma + declspec
    linked_lemma = re.sub(r"\^([;*(])", r"\1", linked_lemma)
    args = [stress, linked_lemma, plstem]
    if not args[0]:
      del args[0]
    if not args[-1]:
      del args[-1]
    args = [":".join(args)]
  return args

def get_lemma(linked_headwords, lemma, multiword, pagemsg):
  if lemma in linked_headwords:
    linked_lemma = linked_headwords[lemma]
  else:
    # Check if we have a linked version of the unstressed version of lemma; happens
    # esp. with monosyllabic words. If so, substituted stressed version into link.
    linked_lemma = linked_headwords.get(make_unstressed_once_ru(lemma), lemma)
    if "|" in linked_lemma:
      linked_lemma = linked_lemma.replace("|" + make_unstressed_once_ru(lemma) + "]]",
          "|" + lemma + "]]")
    elif "[" in linked_lemma:
      linked_lemma = "[[" + lemma + "]]"
  if lemma != linked_lemma:
    pagemsg("Using linked version %s of lemma %s" % (linked_lemma, lemma))
  elif multiword:
    pagemsg("WARNING: Can't find linked version of lemma %s" % lemma)
  return linked_lemma


def infer_word(forms, noungender, linked_headwords, number, numonly, multiword, pagemsg):
  # Check for invariable word
  caseforms = [x for x in forms.values() if x]
  allsame = True
  numsame = 0
  for caseform in caseforms[1:]:
    if caseform != caseforms[0]:
      allsame = False
    else:
      numsame += 1
  if numsame > 6 and not allsame:
    pagemsg("Found almost-invariable word %s: %s same" % (caseforms[0], numsame))
  if allsame:
    lemma = caseforms[0]
    pagemsg("Found invariable word %s" % lemma)
    linked_lemma = get_lemma(linked_headwords, lemma, multiword, pagemsg)
    if is_monosyllabic(lemma) and not is_nonsyllabic(lemma) and not is_stressed(lemma):
      pagemsg("Marking invariable word %s as unaccented" % lemma)
      linked_lemma = "*" + linked_lemma
    if old_template:
      return [linked_lemma, "$"]
    else:
      return [linked_lemma + "$"]

  nompl = forms.get("nom_pl", "")
  accsg = forms.get("acc_sg", "")
  accsg_stress = re.search("[ё́]$", accsg) and "ending" or "stem"
  gensg = forms.get("gen_sg", "")
  genpl = try_to_stress(forms.get("gen_pl", ""))
  presg = forms.get("pre_sg", "")
  prepl = forms.get("pre_pl", "")
  prepl_stress = re.search(AC + "хъ?$", prepl) and "ending" or "stem"
  bare = ""
  genpls = [""]

  # Special case:
  if numonly == "pl" and nompl in ["острова́", "Острова́"]:
    args = generate_template_args("c", nompl, "[[о́стров|%s]]" % nompl, "m(1)", None, pagemsg) + number
    if trymatch(forms, args, pagemsg):
      return args

  if numonly == "pl":
    nomsgs = synthesize_singular(nompl, prepl, noungender, pagemsg)
  else:
    nomsgs = [try_to_stress(forms["nom_sg"])]

  for nomsg in nomsgs:
    lemma = nompl if numonly == "pl" else nomsg
    linked_lemma = get_lemma(linked_headwords, lemma, multiword, pagemsg)
    if numonly == "sg":
      if try_to_stress(forms["acc_sg"]) == try_to_stress(forms["gen_sg"]):
        anim = ["a=an"]
      elif try_to_stress(forms["acc_sg"]) == try_to_stress(forms["nom_sg"]):
        anim = ["a=in"]
      else:
        # Can't check for nom/acc sg equal because feminine nouns have all
        # three different
        anim = []
    else:
      if try_to_stress(forms["acc_pl"]) == try_to_stress(forms["nom_pl"]):
        anim = ["a=in"]
      elif try_to_stress(forms["acc_pl"]) == try_to_stress(forms["gen_pl"]):
        anim = ["a=an"]
      else:
        pagemsg("WARNING: Unable to determine animacy: nom_pl=%s, acc_pl=%s, gen_pl=%s" %
            (forms["nom_pl"], forms["acc_pl"], forms["gen_pl"]))
        return None

    # Adjectives in -ий of the +ьий type, special because they
    # can't be auto-detected
    if re.search("ий$", nomsg) and re.search("ьего$", gensg):
      stem = re.sub("ий$", "", nomsg)
      if old_template:
        args = [linked_lemma, "+ь"] + anim + number
      else:
        args = [linked_lemma + "+ь"] + anim + number
      if trymatch(forms, args, pagemsg):
        return args

    def adj_by_prep():
      return (
        numonly == "sg" and re.search("[ое][мй]$", make_unstressed_once_ru(presg)) or
        numonly != "sg" and re.search("[ыи]х$", make_unstressed_once_ru(prepl)))

    if (re.search("([ыиіо]й|[яаь]я|[оеь]е)$", make_unstressed_once_ru(nomsg)) and
        adj_by_prep()):
      if old_template:
        args = [linked_lemma, "+"] + anim + number
      else:
        args = [linked_lemma + "+"] + anim + number
      if trymatch(forms, args, pagemsg):
        return args

    # I think these are always in -ов/-ев/-ёв/-ин/-ын.
    #if re.search("([шщжчц]е|[ъоа]|)$", nomsg):
    if (re.search("([ое]в|[ыи]н)([оаъ]?)$", make_unstressed_once_ru(nomsg)) and
        adj_by_prep()):
      for adjpat in ["+", "+short", "+mixed", "+proper"]:
        if old_template:
          args = [linked_lemma, adjpat] + anim + number
        else:
          args = [linked_lemma + adjpat] + anim + number
        if trymatch(forms, args, pagemsg):
          return args

    # Ending in -мя, nom pl in either -мена́.
    if re.search("мя$", nomsg):
      args = None
      if numonly == "sg" or re.search("мена́$", nompl):
        if old_template:
          args = ["c", linked_lemma]
        else:
          args = ["c:" + linked_lemma]
      if args:
        args += anim + number
        if trymatch(forms, args, pagemsg):
          return args

    stress = "any"
    plstress = "any"
    if numonly == "pl":
      genders = [noungender]
    else:
      genders = [""]
    strange_genpl = ""
    strange_plural = ""
    plstem = None

    ########## Check for feminine or neuter
    m = re.search(r"^(.*)([аяеоё])(́?)$", nomsg)
    if m:
      pagemsg("Nom sg %s refers to feminine 1st decl or neuter 2nd decl" % nomsg)
      # We use to call try_to_stress() here on the stem but that fails if
      # the stem has е and we stress it as е́ when it should be ё
      stem = m.group(1)
      ending = m.group(2)
      if m.group(3) or ending == "ё":
        stress = "ending"
      else:
        stress = "stem"

      for numrestrict, regex, formcase in [
          ("sg", r"^(.*)[аяыи]́?$", "nom_pl"), # accent patterns d, f
          ("pl", r"^(.*)[уюоеё]́?$", "acc_sg"), # accent patterns d', f'
          ("sg", r"^(.*)([ая]́?х)$", "pre_pl"), # necessary???
        ]:
        if numonly != numrestrict:
          # Try to find a stressed version of the stem using the form case
          if is_unstressed(stem):
            form = forms.get(formcase, "")
            if not form:
              pagemsg("WARNING: Empty or missing %s" % formcase)
              continue
            mm = re.search(regex, form)
            if not mm:
              pagemsg("WARNING: Don't recognize fem 1st-decl or neut 2nd-decl %s ending in form %s" % (formcase, form))
            else:
              formstem = mm.group(1)
              if make_unstressed_once_ru(formstem) != stem:
                pagemsg("%s stem %s not accent-equiv to nom sg stem %s" % (
                  formcase, formstem, stem))
              elif formstem != stem:
                pagemsg("Replacing unstressed stem %s with stressed %s stem %s" %
                    (stem, formcase, formstem))
                stem = formstem

      if numonly != "sg":
        # Check nom pl for strange plural ending or stem
        if "," not in nompl:
          if stem.endswith("ь"):
            # Don't check for -ья ending if stem ends with -ь, because it
            # won't be a strange -ья ending but a normal -я ending with
            # stem in -ь
            mm = re.search("^(.*?)(([иы]|[яа])́?)$", nompl)
          else:
            mm = re.search("^(.*?)((ья|[иы]|[яа])́?)$", nompl)
          if not mm:
            pagemsg("WARNING: Strange nominative plural ending: %s" % nompl)
            return None
          plstem = mm.group(1)
          nomplending = mm.group(2)
          if plstem == stem or plstem == make_unstressed_once_ru(stem) or make_unstressed_once_ru(plstem) == stem:
            plstem = None
          else:
            pagemsg("Found unusual plural stem: %s" % plstem)
          unomplending = make_unstressed_once_ru(nomplending)
          if (ending in ["а", "я"] and unomplending in ["ы", "и"] or
              ending not in ["а", "я"] and unomplending in ["а", "я"]):
            # Not a strange plural
            strange_plural = ""
            pass
          else:
            strange_plural = "-" + unomplending
          if strange_plural:
            pagemsg("Found unusual plural %s" % strange_plural)

        # Look at gen pl to check for reducible and try to get a stressed stem;
        possible_genpls = []
        possible_unstressed_genpls = []
        expected_gen_pls = strange_plural == "-ья" and ["ьев", "ьёв"] or ["", "ь", "й"]
        genplstem = plstem or stem
        for genpl_ending in expected_gen_pls:
          possible_genpls.append(genplstem + genpl_ending)
          possible_unstressed_genpls.append(make_unstressed_once_ru(genplstem + genpl_ending))
        if genpl in possible_genpls:
          pagemsg("Gen pl %s same as stem %s (modulo expected endings)" % (genpl, genplstem))
          genpls = ["", genpl]
        elif make_unstressed_once_ru(genpl) not in possible_unstressed_genpls:
          pagemsg("Stem %s not accent-equiv to gen pl %s (modulo expected endings)" % (genplstem, genpl))
          genpls = ["*", "(2)", "", genpl]
        elif is_unstressed(genplstem):
          pagemsg("Replacing unstressed stem %s with accent-equiv gen pl %s" %
              (stem, genpl))
          # Don't do this; we automatically stress the gen pl stem if required.
          # And in any case this is broken when expected gen pls includes "ьев".
          #if plstem:
          #  plstem = re.sub("[ьй]$", "", genpl)
          #else:
          #  stem = re.sub("[ьй]$", "", genpl)
          genpls = ["", genpl]
        else:
          pagemsg("WARNING: Stem %s stressed one way, gen pl %s stressed differently" %
              (genplstem, genpl))
          genpls = ["", genpl]

      # Auto-stress monosyllabic stem if necessary
      if is_unstressed(stem) and is_unstressed(ending):
        trystress = try_to_stress(stem)
        if trystress != stem:
          pagemsg("Replacing monosyllabic unstressed stem %s with stressed equiv %s" % (stem, trystress))
          stem = trystress

      nomsg = stem + ending

    ########## Check for masculine
    else:
      m = re.search(r"^(.*?)([йь]?)$", nomsg)
      if m:
        nomsgstem = m.group(1)
        ending = m.group(2)
        stem = nomsgstem
        if numonly != "pl":
          m = re.search(r"^(.*)([аяи])(́?)$", gensg)
          if not m:
            pagemsg("WARNING: Don't recognize gen sg ending in form %s" % gensg)
            if ending == "ь":
              genders = ["m", "f"]
          else:
            # We use to call try_to_stress() here on the stem but that fails if
            # the stem has е and we stress it as е́ when it should be ё
            stem = m.group(1)
            # Try to find a stressed version of the stem
            if is_unstressed(stem):
              mm = re.search(r"^(.*)[аяыи]́?$", nompl)
              if not mm:
                pagemsg("WARNING: Don't recognize nom pl ending in form %s" % nompl)
              else:
                nomplstem = mm.group(1)
                if make_unstressed_once_ru(nomplstem) != stem:
                  pagemsg("Nom pl stem %s not accent-equiv to gen sg stem %s" % (
                    nomplstem, stem))
                elif nomplstem != stem:
                  pagemsg("Replacing unstressed stem %s with stressed nom pl stem %s" %
                      (stem, nomplstem))
                  stem = nomplstem
            if ending == "ь":
              if m.group(2) == "я":
                pagemsg("Found masculine soft-stem nom sg %s" % nomsg)
                genders = ["m"]
              else:
                pagemsg("Found feminine soft-stem nom sg %s" % nomsg)
                genders = ["f"]
            elif ending == "й":
              pagemsg("Found masculine palatal-stem nom sg %s" % nomsg)
            else:
              pagemsg("Found masculine consonant-stem nom sg %s" % nomsg)
            if m.group(3):
              stress = "ending"
            else:
              stress = "stem"
            if stem == nomsgstem:
              pagemsg("Nom sg stem %s same as stem" % nomsgstem)
            elif make_unstressed_once_ru(stem) != make_unstressed_once_ru(nomsgstem):
              pagemsg("Stem %s not accent-equiv to nom sg stem %s" % (stem, nomsgstem))
              bare = "*"
            elif is_unstressed(stem):
              pagemsg("Replacing unstressed stem %s with accent-equiv nom sg stem %s" %
                  (stem, nomsgstem))
            else:
              pagemsg("Stem %s stressed one way, nom sg stem %s stressed differently" %
                  (stem, nomsgstem))

        # Check for strange plural
        if numonly != "sg":
          # Check nom pl for strange plural ending or stem
          if "," not in nompl:
            mm = re.search("^(.*?)((ья|[иы]|[яа])́?)$", nompl)
            if not mm:
              pagemsg("WARNING: Strange nominative plural ending: %s" % nompl)
              return None
            plstem = mm.group(1)
            nomplending = mm.group(2)
            if plstem == stem or plstem == make_unstressed_once_ru(stem) or make_unstressed_once_ru(plstem) == stem:
              plstem = None
            else:
              pagemsg("Found unusual plural stem: %s" % plstem)
            unomplending = make_unstressed_once_ru(nomplending)
            if unomplending in ["ы", "и"]:
              # Not a strange plural
              strange_plural = ""
              pass
            else:
              strange_plural = "-" + unomplending
            if strange_plural:
              pagemsg("Found unusual plural %s" % strange_plural)

          # Check for unexpected genitive plural
          genpls = ["", "(2)", genpl]

    # Find stress pattern possibilities
    if numonly != "sg":
      m = re.search(r"[аяыи](́?)$", nompl)
      if m:
        plstress = m.group(1) and "ending" or "stem"
    if numonly == "sg":
      plstress = "none"
    if numonly == "pl":
      stress = "none"
    if stress == "any" or plstress == "any":
      pagemsg("WARNING: Using all stress patterns")
      stress_patterns = all_stress_patterns
    else:
      stress_patterns = matching_stress_patterns[stress][plstress]
      while type(stress_patterns) is dict:
        stress_patterns = stress_patterns[stress_patterns["by"] == "pre_pl" and prepl_stress or accsg_stress]
      if type(stress_patterns) is not list:
        stress_patterns = [stress_patterns]

    if strange_plural and strange_plural != "-ья":
      pagemsg("Replacing unusual plural marker %s with (1)" % (strange_plural))
      strange_plural = "(1)"
    if ("ё" in nomsg or "ё" in nompl or "ё" in genpl) and "ё" not in lemma:
      strange_plural += ";ё"
    for stress in stress_patterns:
      for gender in genders:
        for genplval in genpls:
          declspec = gender + strange_plural + bare
          genplargs = []
          if genplval in ["*", "(2)"]:
            declspec += genplval
          elif genplval:
            genplargs.append("gen_pl=%s" % genplval)
          args = generate_template_args(stress, lemma, linked_lemma, declspec, plstem, pagemsg)
          args += genplargs
          args += anim + number
          if trymatch(forms, args, pagemsg):
            return args

  return None

def infer_one_page_decls_1(page, index, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, str(page.title()), txt))
  genders = set()
  headwords = set()
  # Extract the genders and the headwords
  for t in text.filter_templates():
    if str(t.name).strip() in ["ru-noun", "ru-proper noun"]:
      m = re.search("^([mfn])", getparam(t, "2"))
      if not m:
        pagemsg("WARNING: Strange ru-noun template: %s" % str(t))
      else:
        genders.add(m.group(1))
      head = getparam(t, "1")
      if head:
        headwords.add(head)
      for i in range(2, 10):
        head = getparam(t, "head" + str(i))
        if head:
          headwords.add(head)
  # Extract a map of headword elements and the links involving them
  split_headwords = set()
  for headword in headwords:
    splitvals = re.split(r"(\[\[[^\[\]]*\]\])", headword)
    for i in range(len(splitvals)):
      if i % 2 == 1:
        split_headwords.add(splitvals[i])
  linked_headwords = {}
  for linked_headword in split_headwords:
    linked_word = blib.remove_links(linked_headword)
    if linked_word in linked_headwords and linked_headwords[linked_word] != linked_headword:
      pagemsg("WARNING: Found different links %s and %s for word %s in headword" % (
        linked_headwords[linked_word], linked_headword, linked_word))
    linked_headwords[linked_word] = linked_headword

  inferred_decls = []
  for t in text.filter_templates():
    if str(t.name).strip() in manual_templates:
      if str(t.name).strip() == "ru-decl-noun-pl":
        genders = list(genders)
        if len(genders) == 0:
          pagemsg("WARNING: Can't find gender for pl-only nominal")
          continue
        elif len(genders) > 1:
          pagemsg("WARNING: Multiple genders found for pl-only nominal: %s" %
              genders)
          continue
        else:
          gender = genders[0]
      else:
        gender = ""
      args = infer_decl(t, gender, linked_headwords, pagemsg)
      if args:
        inferred_decls.append("{{%s|%s}}" % (decl_template, "|".join(args)))
        for i in range(15, 0, -1):
          rmparam(t, i)
        t.name = decl_template
        i = 1
        for arg in args:
          if "=" in arg:
            name, value = re.split("=", arg)
            t.add(name, value)
          else:
            t.add(i, arg)
            i += 1
  return text, "Infer declension for manual decl(s): %s" % ", ".join(inferred_decls)

def infer_one_page_decls(page, index, text):
  try:
    return infer_one_page_decls_1(page, index, text)
  except StandardError as e:
    msg("%s %s: WARNING: Got an error: %s" % (index, str(page.title()), repr(e)))
    traceback.print_exc(file=sys.stdout)
    return text, "no change"

test_templates = [
  """{{ru-decl-noun
    |сре́дний па́лец|сре́дние па́льцы
    |сре́днего па́льца|сре́дних па́льцев
    |сре́днему па́льцу|сре́дним па́льцам
    |сре́дний па́лец|сре́дние па́льцы
    |сре́дним па́льцем|сре́дними па́льцами
    |о сре́днем па́льце|о сре́дних па́льцах}}""",
  """{{ru-decl-noun
    |лист Мёбиуса|листы́ Мёбиуса
    |листа́ Мёбиуса|листо́в Мёбиуса
    |листу́ Мёбиуса|листа́м Мёбиуса
    |лист Мёбиуса|листы́ Мёбиуса
    |листо́м Мёбиуса|листа́ми Мёбиуса
    |о листе́ Мёбиуса|о листа́х Мёбиуса}}""",
  """{{ru-decl-noun|ма́льчик для битья́|ма́льчики для битья́|ма́льчика для битья́|ма́льчиков для битья́|ма́льчику для битья́|ма́льчикам для битья́|ма́льчика для битья́|ма́льчиков для битья́|ма́льчиком для битья́|ма́льчиками для битья́|о ма́льчике для битья́|о ма́льчиках для битья́}}""",
  """{{ru-decl-noun
  |ба́бье ле́то|ба́бьи лета́
  |ба́бьего ле́та|ба́бьих лет
  |ба́бьему ле́ту|ба́бьим лета́м
  |ба́бье ле́то|ба́бьи лета́
  |ба́бьим ле́том|ба́бьими лета́ми
  |о ба́бьем ле́те|о ба́бьих лета́х}}""",
  """{{ru-decl-noun
  |часть ре́чи|ча́сти ре́чи
  |ча́сти ре́чи|часте́й ре́чи
  |ча́сти ре́чи|частя́м ре́чи
  |часть ре́чи|ча́сти ре́чи
  |ча́стью ре́чи|частя́ми ре́чи
  |о ча́сти ре́чи|о частя́х ре́чи}}""",
  """{{ru-decl-noun
  |де́тская|де́тские
  |де́тской|де́тских
  |де́тской|де́тским
  |де́тскую|де́тские
  |де́тской|де́тскими
  |о де́тской|о де́тских}}""",
  """{{ru-decl-noun|медоно́сная пчела́|медоно́сные пчёлы|медоно́сной пчелы́|медоно́сных пчёл|медоно́сной пчеле́|медоно́сным пчёлам|медоно́сную пчелу́|медоно́сных пчёл|медоно́сной пчело́й|медоно́сными пчёлами|о медоно́сном пчеле́|о медоно́сных пчёлах}}""",
  """{{ru-decl-noun
  |истреби́тель-бомбардиро́вщик|истреби́тели-бомбардиро́вщики
  |истреби́теля-бомбардиро́вщика|истреби́телей-бомбардиро́вщиков
  |истреби́телю-бомбардиро́вщику|истреби́телям-бомбардиро́вщикам
  |истреби́тель-бомбардиро́вщик|истреби́тели-бомбардиро́вщики
  |истреби́телем-бомбардиро́вщиком|истреби́телями-бомбардиро́вщиками
  |об истреби́теле-бомбардиро́вщике|об истреби́телях-бомбардиро́вщиках}}""",
  """{{ru-decl-noun
  |ко́свенный паде́ж|ко́свенные падежи́
  |ко́свенного падежа́|ко́свенных падеже́й
  |ко́свенному падежу́|ко́свенным падежа́м
  |ко́свенный паде́ж|ко́свенные падежи́
  |ко́свенным падежо́м|ко́свенными падежа́ми
  |о ко́свенном падеже́|о ко́свенных падежа́х}}""",
  """{{ru-decl-noun
  |кусо́к дерьма́|куски́ дерьма́
  |куска́ дерьма́|куско́в дерьма́
  |куску́ дерьма́|куска́м дерьма́
  |кусо́к дерьма́|куски́ дерьма́
  |куско́м дерьма́|куска́ми дерьма́
  |о куске́ дерьма́|о куска́х дерьма́}}""",
  """{{ru-decl-noun
  |противота́нковый ёж|противота́нковые ежи́
  |противота́нкового ежа́|противота́нковых еже́й
  |противота́нковому ежу́|противота́нковым ежа́м
  |противота́нковый ёж|противота́нковые ежи́
  |противота́нковым ежо́м|противота́нковыми ежа́ми
  |о противота́нковом еже́|о противота́нковых ежа́х}}""",
  """{{ru-decl-noun
  |а́рмия Соединённых Шта́тов Аме́рики|а́рмии Соединённых Шта́тов Аме́рики
  |а́рмии Соединённых Шта́тов Аме́рики|а́рмий Соединённых Шта́тов Аме́рики
  |а́рмии Соединённых Шта́тов Аме́рики|а́рмиям Соединённых Шта́тов Аме́рики
  |а́рмию Соединённых Шта́тов Аме́рики|а́рмии Соединённых Шта́тов Аме́рики
  |а́рмией Соединённых Шта́тов Аме́рики|а́рмиями Соединённых Шта́тов Аме́рики
  |об а́рмии Соединённых Шта́тов Аме́рики|об а́рмиях Соединённых Шта́тов Аме́рики}}""",
  """{{ru-decl-noun
  |дезоксирибонуклеи́новая кислота́|дезоксирибонуклеи́новые кисло́ты
  |дезоксирибонуклеи́новой кислоты́|дезоксирибонуклеи́новых кисло́т
  |дезоксирибонуклеи́новой кислоте́|дезоксирибонуклеи́новым кисло́там
  |дезоксирибонуклеи́новую кислоту́|дезоксирибонуклеи́новые кисло́ты
  |дезоксирибонуклеи́новой кислото́й|дезоксирибонуклеи́новыми кисло́тами
  |о дезоксирибонуклеи́новой кислоте́|о дезоксирибонуклеи́новых кисло́тах}}""",
  """{{ru-decl-noun
  |Ба́ба-Яга́|Ба́бы-Яги́
  |Ба́бы-Яги́|Баб-Яг
  |Ба́бе-Яге́|Ба́бам-Яга́м
  |Ба́бу-Ягу́|Баб-Яг
  |Ба́бой-Яго́й|Ба́бами-Яга́ми
  |о Ба́бе-Яге́|о Ба́бах-Яга́х}}""",
  """{{ru-decl-noun
  |кори́чное де́рево|кори́чные дере́вья
  |кори́чного де́рева|кори́чных дере́вьев
  |кори́чному де́реву|кори́чным дере́вьям
  |кори́чное де́рево|кори́чные дере́вья
  |кори́чным де́ревом|кори́чными дере́вьями
  |о кори́чном де́реве|о кори́чных дере́вьях}}""",
  """{{ru-decl-noun
  |щётка для ресни́ц|щётки для ресни́ц
  |щётки для ресни́ц|щёток для ресни́ц
  |щётке для ресни́ц|щёткам для ресни́ц
  |щётку для ресни́ц|щётки для ресни́ц
  |щёткой для ресни́ц|щётками для ресни́ц
  |о щётке для ресни́ц|о щётках для ресни́ц}}""",
  """{{ru-decl-noun
  |учи́тель|учителя́
  |учи́теля|учителе́й
  |учи́телю|учителя́м
  |учи́теля|учителе́й
  |учи́телем|учителя́ми
  |учи́теле|учителя́х
  }}""",
  """{{ru-decl-noun
  |учи́тель|учителя́, учители́
  |учи́теля|учителе́й
  |учи́телю|учителя́м
  |учи́теля|учителе́й
  |учи́телем|учителя́ми
  |учи́теле|учителя́х
  }}""",
  """{{ru-decl-noun
  |пе́рвое лицо́|пе́рвые ли́ца
  |пе́рвого лица́|пе́рвых лиц
  |пе́рвому лицу́|пе́рвым ли́цам
  |пе́рвое лицо́|пе́рвые ли́ца
  |пе́рвым лицо́м|пе́рвыми ли́цами
  |о пе́рвом лице́|о пе́рвых ли́цах}}""",
  """{{ru-decl-noun
  |тре́тье лицо́|тре́тьи ли́ца
  |тре́тьего лица́|тре́тьих лиц
  |тре́тьему лицу́|тре́тьим ли́цам
  |тре́тье лицо́|тре́тьи ли́ца
  |тре́тьим лицо́м|тре́тьими ли́цами
  |о тре́тьем лице́|о тре́тьих ли́цах}}""",
  """====Declension====
  {{ru-decl-noun
  |отглаго́льное существи́тельное|отглаго́льные существи́тельные
  |отглаго́льного существи́тельного|отглаго́льных существи́тельных
  |отглаго́льному существи́тельному|отглаго́льным существи́тельным
  |отглаго́льное существи́тельное|отглаго́льные существи́тельные
  |отглаго́льным существи́тельным|отглаго́льными существи́тельными
  |об отглаго́льном существи́тельном|об отглаго́льных существи́тельных}}""",
  """{{ru-decl-noun
  |кра́сное смеще́ние|кра́сные смеще́ния
  |кра́сного смеще́ния|кра́сных смеще́ний
  |кра́сному смеще́нию|кра́сным смеще́ниям
  |кра́сное смеще́ние|кра́сные смеще́ния
  |кра́сным смеще́нием|кра́сными смеще́ниями
  |о кра́сном смеще́нии|о кра́сных смеще́ниях}}""",
  """{{ru-decl-noun
  |кардина́льное число́|кардина́льные чи́сла
  |кардина́льного числа́|кардина́льных чи́сел
  |кардина́льному числу́|кардина́льным чи́слам
  |кардина́льное число́|кардина́льные чи́сла
  |кардина́льным число́м|кардина́льными чи́слами
  |о кардина́льном числе́|о кардина́льных чи́слах}}""",
  """{{ru-decl-noun
  |страна́ све́та|стра́ны све́та
  |страны́ све́та|стран све́та
  |стране́ све́та|стра́нам све́та
  |страну́ све́та|стра́ны све́та
  |страно́й све́та|стра́нами све́та
  |о стране́ све́та|о стра́нах све́та}}""",
  """{{ru-decl-noun
  |и́мя числи́тельное|имена́ числи́тельные
  |и́мени числи́тельного|имён числи́тельных
  |и́мени числи́тельному|имена́м числи́тельным
  |и́мя числи́тельное|имена́ числи́тельные
  |и́менем числи́тельным|имена́ми числи́тельными
  |об и́мени числи́тельном|об имена́х числи́тельных}}""",
  """{{ru-decl-noun
  |мужско́й полово́й член|мужски́е половы́е чле́ны
  |мужско́го полово́го чле́на|мужски́х половы́х чле́нов
  |мужско́му полово́му чле́ну|мужски́м половы́м чле́нам
  |мужско́й полово́й член|мужски́е половы́е чле́ны
  |мужски́м половы́м чле́ном|мужски́ми половы́ми чле́нами
  |мужско́м полово́м чле́не|мужски́х половы́х чле́нах}}""",
  """{{ru-decl-noun
  |варёное яйцо́|варёные я́йца
  |варёного яйца́|варёных яи́ц
  |варёному яйцу́|варёным я́йцам
  |варёное яйцо́|варёные я́йца
  |варёным яйцо́м|варёными я́йцами
  |о варёном яйце́|о варёных я́йцах}}""",
  """{{ru-decl-noun
  |коренно́й зуб|коренны́е зу́бы
  |коренно́го зу́ба|коренны́х зубо́в
  |коренно́му зу́бу|коренны́м зуба́м
  |коренно́й зуб|коренны́е зу́бы
  |коренны́м зу́бом|коренны́ми зуба́ми
  |о коренно́м зу́бе|о коренны́х зуба́х}}""",
  """{{ru-decl-noun
  |зени́тный пулемёт|зени́тные пулемёты
  |зени́тного пулемёта|зени́тных пулемётов
  |зени́тному пулемёту|зени́тным пулемётам
  |зени́тный пулемёт|зени́тные пулемёты
  |зени́тным пулемётом|зени́тными пулемётами
  |о зени́тном пулемёте|о зени́тных пулемётах}}""",
  """{{ru-decl-noun
  |вре́мя го́да|времена́ го́да
  |вре́мени го́да|времён го́да
  |вре́мени го́да|времена́м го́да
  |вре́мя го́да|времена́ го́да
  |вре́менем го́да|времена́ми го́да
  |о вре́мени го́да|о времена́х го́да}}""",
  """{{ru-decl-noun
  |трёхэта́жное сло́во|трёхэта́жные слова́
  |трёхэта́жного сло́ва|трёхэта́жных слов
  |трёхэта́жному сло́ву|трёхэта́жным слова́м
  |трёхэта́жное сло́во|трёхэта́жные слова́
  |трёхэта́жным сло́вом|трёхэта́жными слова́ми
  |трёхэта́жном сло́ве|трёхэта́жных слова́х}}""",
  """{{ru-decl-noun
  |шишкови́дная железа́|шишкови́дные же́лезы
  |шишкови́дной железы́|шишкови́дных желёз
  |шишкови́дной железе́|шишкови́дным железа́м
  |шишкови́дную железу́|шишкови́дные же́лезы
  |шишкови́дной железо́й|шишкови́дными железа́ми
  |о шишкови́дной железе́|о шишкови́дных железа́х}}""",
  """{{ru-decl-noun
  |кастрю́лька молока́|кастрю́льки молока́
  |кастрю́льки молока́|кастрю́лек молока́
  |кастрю́льке молока́|кастрю́лькам молока́
  |кастрю́льку молока́|кастрю́льки молока́
  |кастрю́лькой молока́|кастрю́льками молока́
  |о кастрю́льке молока́|о кастрю́льках молока́}}""",
  """{{ru-decl-noun
  |пау́к-во́лк|пауки́-во́лки
  |паука́-во́лка|пауко́в-волко́в
  |пауку́-во́лку|паука́м-волка́м
  |паука́-во́лка|пауко́в-волко́в
  |пауко́м-во́лком|паука́ми-волка́ми
  |о пауке́-во́лке|о паука́х-волка́х}}""",
  """{{ru-decl-noun
  |ка́рточная игра́|ка́рточные и́гры
  |ка́рточной игры́|ка́рточных игр
  |ка́рточной игре́|ка́рточным и́грам
  |ка́рточную игру́|ка́рточные и́гры
  |ка́рточной игро́й|ка́рточными и́грами
  |о ка́рточной игре́|о ка́рточных и́грах}}""",
  """{{ru-decl-noun
  |ско́рая по́мощь|ско́рые по́мощи
  |ско́рой по́мощи|ско́рых по́мощей
  |ско́рой по́мощи|ско́рым по́мощам
  |ско́рую по́мощь|ско́рые по́мощи
  |ско́рой по́мощью|ско́рыми по́мощами
  |о ско́рой по́мощи|о ско́рых по́мощах}}""",
  """{{ru-decl-noun
  |со́лнечный ве́тер|со́лнечные ве́тры
  |со́лнечного ве́тра|со́лнечных ветро́в
  |со́лнечному ве́тру|со́лнечным ветра́м
  |со́лнечный ве́тер|со́лнечные ве́тры
  |со́лнечным ве́тром|со́лнечными ветра́ми
  |со́лнечном ве́тре|со́лнечных ветра́х
  }}""",
  """{{ru-decl-noun
  |монго́льский язы́к|монго́льские языки́
  |монго́льского языка́|монго́льских языко́в
  |монго́льскому языку́|монго́льским языка́м
  |монго́льский язы́к|монго́льские языки́
  |монго́льским языко́м|монго́льскими языка́ми
  |о монго́льском языке́|о монго́льских языка́х}}""",
  """{{ru-decl-noun
  |головна́я боль|головны́е бо́ли|головно́й бо́ли|головны́х бо́лей|головно́й бо́ли|головны́м
   бо́лям|головну́ю боль|головны́е бо́ли|головно́й бо́лью|головны́ми бо́лями|о головно́й бо́ли|о головны́х бо́лях}}""",
  """{{ru-decl-noun-unc|Столи́чная
  |Столи́чной
  |Столи́чной
  |Столи́чную
  |[[Столи́чной]], [[Столи́чною]]
  |о Столи́чной}}""",
  """{{ru-decl-noun-unc
  |несоверше́нный вид
  |несоверше́нного ви́да
  |несоверше́нному ви́ду
  |несоверше́нный вид
  |несоверше́нным ви́дом
  |о несоверше́нном ви́де|}}""",
  """{{ru-decl-noun-unc
  |Бо́сния и Герцегови́на
  |Бо́снии и Герцегови́ны
  |Бо́снии и Герцегови́не
  |Бо́снию и Герцегови́ну
  |Бо́снией и Герцегови́ной
  |о Бо́снии и Герцегови́не}}""",
  """{{ru-decl-noun-unc
  |Росси́йская Сове́тская Федерати́вная Социалисти́ческая Респу́блика
  |Росси́йской Сове́тской Федерати́вной Социалисти́ческой Респу́блики
  |Росси́йской Сове́тской Федерати́вной Социалисти́ческой Респу́блике
  |Росси́йскую Сове́тскую Федерати́вную Социалисти́ческую Респу́блику
  |Росси́йской Сове́тской Федерати́вной Социалисти́ческой Респу́бликой
  |о Росси́йской Сове́тской Федерати́вной Социалисти́ческой Респу́блике|}}""",
  """{{ru-decl-noun-unc
  |Ма́лая Азия
  |Ма́лой Азии
  |Ма́лой Азии
  |Ма́лую Азию
  |Ма́лой Азией, Ма́лою Азиею
  |о Ма́лой Азии}}""",
  """{{ru-decl-noun-unc
  |Жёлтая река́
  |Жёлтой реки́
  |Жёлтой реке́
  |Жёлтую ре́ку
  |Жёлтой реко́й
  |о Жёлтой реке́}}""",
  """{{ru-decl-noun-unc|
  Дже́к-Потроши́тель|
  Дже́ка-Потроши́теля|
  Дже́ку-Потроши́телю|
  Дже́ка-Потроши́теля|
  Дже́ком-Потроши́телем|
  Дже́ке-Потроши́теле|}}""",
  """{{ru-decl-noun-unc
  |ни́жнее бельё
  |ни́жнего белья́
  |ни́жнему белью́
  |ни́жнее бельё
  |ни́жним бельём
  |ни́жнем белье́}}""",
  """{{ru-decl-noun-unc
  |Алта́йский край
  |Алта́йского кра́я
  |Алта́йскому кра́ю
  |Алта́йский край
  |Алта́йским кра́ем
  |об Алта́йском кра́е}}""",
  """{{ru-decl-noun-unc|мавзоле́й в Галикарна́се
  |мавзоле́я в Галикарна́се
  |мавзоле́ю в Галикарна́се
  |мавзоле́й в Галикарна́се
  |мавзоле́ем в Галикарна́се
  |о мавзоле́е в Галикарна́се}}""",
  """{{ru-decl-noun-unc
  |коро́вье бе́шенство
  |коро́вьего бе́шенства
  |коро́вьему бе́шенству
  |коро́вье бе́шенство
  |коро́вьим бе́шенством
  |о коро́вьем бе́шенстве}}""",
  """{{ru-decl-noun-unc
  |го́ре лу́ковое
  |го́ря лу́кового
  |го́рю лу́ковому
  |го́ре лу́ковое
  |го́рем лу́ковым
  |о го́ре лу́ковом}}""",
  """{{ru-decl-noun-unc
  |Шалта́й-Болта́й
  |Шалта́я-Болта́я
  |Шалта́ю-Болта́ю
  |Шалта́я-Болта́я
  |Шалта́ем-Болта́ем
  |о Шалта́е-Болта́е}}""",
  """{{ru-decl-noun-unc
  |разо́к
  |-
  |-
  |разо́к
  |-
  |-
  }}""",
  """{{ru-decl-noun|я́блоко раздо́ра|я́блоки раздо́ра|я́блока раздо́ра|я́блок раздо́ра|я́блоку раздо́ра|я́блокам раздо́ра|я́блоко раздо́ра|я́блоки раздо́ра|я́блоком раздо́ра|я́блоками раздо́ра|я́блоке раздо́ра|я́блоках раздо́ра}}""",
  """{{ru-decl-noun
  |катапульти́руемое сиде́нье|катапульти́руемые сиде́нья
  |катапульти́руемого сиде́нья|катапульти́руемых сиде́ний
  |катапульти́руемому сиде́нью|катапульти́руемым сиде́ньям
  |катапульти́руемое сиде́нье|катапульти́руемые сиде́нья
  |катапульти́руемым сиде́ньем|катапульти́руемыми сиде́ньями
  |о катапульти́руемом сиде́нье|о катапульти́руемых сиде́ньях}}""",
  """{{ru-decl-noun
  |зубно́й врач|зубны́е врачи́
  |зубно́го врача́|зубны́х враче́й
  |зубно́му врачу́|зубны́м врача́м
  |зубно́го врача́|зубны́х враче́й
  |зубны́м врачо́м|зубны́ми врача́ми
  |о зубно́м враче́|о зубны́х врача́х}}""",
  """{{ru-decl-noun
  |а́белево кольцо́|а́белевы ко́льца
  |а́белева кольца́|а́белевых коле́ц
  |а́белеву кольцу́|а́белевым ко́льцам
  |а́белево кольцо́|а́белевы ко́льца
  |а́белевым кольцо́м|а́белевыми ко́льцами
  |об а́белевом кольце́|об а́белевых ко́льцах}}""",
  """{{ru-decl-noun
  |бо́жья коро́вка|бо́жьи коро́вки
  |бо́жьей коро́вки|бо́жьих коро́вок
  |бо́жьей коро́вке|бо́жьим коро́вкам
  |бо́жью коро́вку|бо́жьих коро́вок
  |бо́жьей коро́вкой|бо́жьими коро́вками
  |о бо́жьей коро́вке|о бо́жьих коро́вках}}""",
  """{{ru-decl-noun|ро́г изоби́лия|рога́ изоби́лия
  |ро́га изоби́лия|рого́в изоби́лия
  |ро́гу изоби́лия|рога́м изоби́лия
  |ро́г изоби́лия|рога́ изоби́лия
  |ро́гом изоби́лия|рога́ми изоби́лия
  |ро́ге изоби́лия|рога́х изоби́лия}}""",
  """{{ru-decl-noun
  |кра́йняя плоть|кра́йние пло́ти
  |кра́йней пло́ти|кра́йних пло́тей
  |кра́йней пло́ти|кра́йним пло́тям
  |кра́йнюю плоть|кра́йние пло́ти
  |кра́йней пло́тью|кра́йними пло́тями
  |кра́йней пло́ти|кра́йних пло́тях
  }}""",
  """{{ru-decl-noun|расти́тельное ма́сло|расти́тельные масла́|расти́тельного ма́сла|расти́тельных ма́сел|расти́тельному ма́слу|расти́тельным масла́м|расти́тельное ма́сло|расти́тельные масла́|расти́тельным ма́слом|расти́тельными масла́ми|расти́тельном ма́сле|расти́тельных масла́х}}""",
  """{{ru-decl-noun
  |минера́льная вода́|минера́льные во́ды
  |минера́льной воды́|минера́льных вод
  |минера́льной воде́|минера́льным во́дам
  |минера́льную во́ду|минера́льные во́ды
  |минера́льной водо́й|минера́льными во́дами
  |о минера́льной воде́|о минера́льных во́дах}}""",
  """{{ru-decl-noun|драгоце́нный ка́мень|драгоце́нные ка́мни|драгоце́нного ка́мня|драгоце́нных камне́й|драгоце́нному ка́мню|драгоце́нным камня́м|драгоце́нный ка́мень|драгоце́нные ка́мни|драгоце́нным ка́мнем|драгоце́нными камня́ми|о драгоце́нном ка́мне|о драгоце́нных камня́х}}""",
  """{{ru-decl-noun|ветрово́е стекло́|ветровы́е стёкла|ветрово́го стекла́|ветровы́х стёкол|ветрово́му стеклу́|ветровым стёклам|ветрово́е стекло́|ветровы́е стёкла|ветровы́м стекло́м|ветровы́ми стёклами|о ветрово́м стекле́|о ветровы́х стёклах}}"""
  """{{ru-decl-noun
  |прямо́й у́гол|прямы́е углы́
  |прямо́го угла́|прямы́х угло́в
  |прямо́му углу́|прямы́м угла́м
  |прямо́й у́гол|прямы́е углы́
  |прямы́м угло́м|прямы́ми угла́ми
  |о прямо́м угле́|о прямы́х угла́х}}""",
  """{{ru-decl-noun
  |глазно́е я́блоко|глазны́е я́блоки
  |глазно́го я́блока|глазны́х я́блок
  |глазно́му я́блоку|глазны́м я́блокам
  |глазно́е я́блоко|глазны́е я́блоки
  |глазны́м я́блоком|глазны́ми я́блоками
  |о глазно́м я́блоке|о глазны́х я́блоках}}""",
  """{{ru-decl-noun
  |раствори́мый ко́фе|раствори́мые ко́фе
  |раствори́мого ко́фе|раствори́мых ко́фе
  |раствори́мому ко́фе|раствори́мым ко́фе
  |раствори́мый ко́фе|раствори́мые ко́фе
  |раствори́мым ко́фе|раствори́мыми ко́фе
  |о раствори́мом ко́фе|о раствори́мых ко́фе}}""",
  """{{ru-decl-noun
  |небе́сное те́ло|небе́сные тела́
  |небе́сного те́ла|небе́сных те́л
  |небе́сному те́лу|небе́сным тела́м
  |небе́сное те́ло|небе́сные тела́
  |небе́сным те́лом|небе́сными тела́ми
  |о небе́сном те́ле|о небе́сных тела́х}}""",
  """{{ru-decl-noun|мы́льный пузы́рь|мы́льные пузыри́
  |мы́льного пузыря́|мы́льных пузыре́й
  |мы́льному пузырю́|мы́льным пузыря́м
  |мы́льный пузы́рь|мы́льные пузыри́
  |мы́льным пузырём|мы́льными пузыря́ми
  |о мы́льном пузыре́|о мы́льных пузыря́х}}""",
  """{{ru-decl-noun
  |ско́рая по́мощь|ско́рые по́мощи
  |ско́рой по́мощи|ско́рых по́мощей
  |ско́рой по́мощи|ско́рым по́мощам
  |ско́рую по́мощь|ско́рые по́мощи
  |ско́рой по́мощью|ско́рыми по́мощами
  |о ско́рой по́мощи|о ско́рых по́мощах}}""",
  """{{ru-decl-noun|со́ня-полчо́к|со́ни-полчки́
  |со́ни-полчка́|сонь-полчко́в
  |со́не-полчку́|со́ням-полчка́м
  |со́ню-полчка́|со́нь-полчко́в
  |со́ней-полчко́м,<br/>со́нею-полчко́м|со́нями-полчка́ми
  |о со́не-полчке́|о со́нях-полчка́х}}""",
  """{{ru-decl-noun
  |су́дно на возду́шной поду́шке|суда́ на возду́шной поду́шке
  |су́дна на возду́шной поду́шке|судо́в на возду́шной поду́шке
  |су́дну на возду́шной поду́шке|суда́м на возду́шной поду́шке
  |су́дно на возду́шной поду́шке|суда́ на возду́шной поду́шке
  |су́дном на возду́шной поду́шке|суда́ми на возду́шной поду́шке
  |о су́дне на возду́шной поду́шке|о суда́х на возду́шной поду́шке}}""",
  """{{ru-decl-noun
  |светово́й го́д|световы́е го́ды
  |светово́го го́да|световы́х ле́т
  |светово́му го́ду|световы́м года́м
  |светово́й го́д|световы́е го́ды
  |световы́м го́дом|световы́ми года́ми
  |о светово́м го́де|о световы́х года́х}}""",
  """{{ru-decl-noun
  |маши́нно-чита́емый слова́рь|маши́нно-чита́емые словари́
  |маши́нно-чита́емого словаря́|маши́нно-чита́емых словаре́й
  |маши́нно-чита́емому словарю́|маши́нно-чита́емым словаря́м
  |маши́нно-чита́емый слова́рь|маши́нно-чита́емые словари́
  |маши́нно-чита́емым словарём|маши́нно-чита́емыми словаря́ми
  |о маши́нно-чита́емом словаре́|о маши́нно-чита́емых словаря́х}}""",
  """{{ru-proper noun|[[британский|Брита́нские]] [[остров|острова́]]|m-in-p}}
  
  # [[British Isles]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |Брита́нские острова́
  |Брита́нских острово́в
  |Брита́нским острова́м
  |Брита́нские острова́
  |Брита́нскими острова́ми
  |о Брита́нских острова́х}}""",
  """{{ru-proper noun|[[остров|острова́]] Уо́ллис и Футу́на|m-in-p}}
  
  # [[Wallis and Futuna]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |острова́ Уо́ллис и Футу́на
  |острово́в Уо́ллис и Футу́на
  |острова́м Уо́ллис и Футу́на
  |острова́ Уо́ллис и Футу́на
  |острова́ми Уо́ллис и Футу́на
  |об острова́х Уо́ллис и Футу́на}}""",
  """{{ru-proper noun|[[Соломон|Соломо́новы]] [[остров|острова́]]|m-in-p}}
  
  # [[Solomon Islands]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |Соломо́новы острова́
  |Соломо́новых острово́в
  |Соломо́новым острова́м
  |Соломо́новы острова́
  |Соломо́новыми острова́ми
  |о Соломо́новых острова́х}}""",
  """{{ru-noun|[[карманный|карма́нные]] [[часы́]]|m-in-p}}
  
  # [[pocket watch]] {{gloss|watch}}
  
  ====Declension====
  {{ru-decl-noun-pl
  |карма́нные часы́
  |карма́нных часо́в
  |карма́нным часа́м
  |карма́нные часы́
  |карма́нными часа́ми
  |о карма́нных часа́х}}""",
  """{{ru-noun|[[сухопутный|сухопу́тные]] [[сила|си́лы]]|f-in-p}}
  
  # {{context|military|lang=ru}} [[land]] [[forces]], [[army]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |сухопу́тные си́лы
  |сухопу́тных сил
  |сухопу́тным си́лам
  |сухопу́тные си́лы
  |сухопу́тными си́лами
  |о сухопу́тных си́лах}}""",
  """{{ru-noun|[[танковый|та́нковые]] [[войско|войска́]]|n-p}}
  
  # {{context|military|lang=ru}} [[armored]] [[troops]], [[armoured]] [[troops]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |та́нковые войска́
  |та́нковых во́йск
  |та́нковым войска́м
  |та́нковые войска́
  |та́нковыми войска́ми
  |о та́нковых войска́х}}""",
  """{{ru-noun|[[брю́ки]]-[[галифе́]]|tr=brjúki-galifɛ́|f-in-p}}
  
  # {{context|military|lang=ru}} [[flared]] [[breeches]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |брю́ки-галифе́
  |брюк-галифе́
  |брю́кам-галифе́
  |брю́ки-галифе́
  |брю́ками-галифе́
  |о брю́ках-галифе́}}""",
  """{{ru-proper noun|[[объединённый|Объединённые]] [[нация|На́ции]]|f-in-p}}
  
  # [[United Nations]]
  
  ====Synonyms====
  * [[Организация Объединённых Наций]]
  
  ====Declension====
  {{ru-decl-noun-pl|Объединённые На́ции|Объединённых На́ций|Объединённым На́циям|Объединённые На́ции|Объединёнными На́циями|Объединённых На́циях}}""",]
def test_infer():
  class Page:
    def title(self):
      return "test_infer"
  for pagetext in test_templates:
    text = blib.parse_text(pagetext)
    page = Page()
    msg("original text = [[%s]]" % pagetext)
    newtext, comment = infer_one_page_decls(page, 1, text)
    msg("newtext = %s" % str(newtext))
    msg("comment = %s" % comment)

parser = blib.create_argparser("Add pronunciation sections to Russian Wiktionary entries")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def ignore_page(page):
  if not isinstance(page, str):
    page = str(page.title())
  if re.search(r"^(Appendix|Appendix talk|User|User talk|Talk):", page):
    return True
  return False

if mockup:
  test_infer()
else:
  for template in manual_templates:
    for index, page in blib.references("Template:" + template, start, end):
      if ignore_page(page):
        msg("Page %s %s: Skipping due to namespace" % (index, str(page.title())))
      else:
        blib.do_edit(page, index, infer_one_page_decls, save=args.save)

