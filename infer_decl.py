#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import pywikibot
import mwparserfromhell
import blib
from blib import msg, rmparam, getparam

save = False

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

all_stress_patterns = ["1", "2", "3", "4", "5", "6", "4*", "6*"]
matching_stress_patterns = {}
matching_stress_patterns["stem"] = {}
matching_stress_patterns["ending"] = {}
matching_stress_patterns["none"] = {}
matching_stress_patterns["stem"]["stem"] = ["1", "5"]
matching_stress_patterns["stem"]["ending"] = ["3"]
matching_stress_patterns["ending"]["stem"] = ["4", "4*", "6", "6*"]
matching_stress_patterns["ending"]["ending"] = ["2"]
matching_stress_patterns["stem"]["none"] = ["1"]
matching_stress_patterns["ending"]["none"] = ["2", "6*"]
matching_stress_patterns["none"]["stem"] = ["1", "6"]
matching_stress_patterns["none"]["ending"] = ["2"]

site = pywikibot.Site()

def trymatch(forms, args):
  tempcall = "{{ru-noun-forms|" + "|".join(args) + "}}"
  result = site.expand_text(tempcall)
  pred_forms = {}
  for formspec in re.split(r"\|", result):
    case, value = re.split(r"=", formspec, 1)
    pred_forms[case] = value
  ok = True
  for case in all_cases:
    pred_form = pred_forms.get(case, "")
    real_form = forms.get(case, "")
    if pred_form and not real_form:
      msg("Missing actual form for case %s (predicted %s)" % (case, pred_form))
      ok = False
    elif real_form and not pred_form:
      msg("Actual has extra form %s=%s not in predicted" % (case, real_form))
      ok = False
    elif pred_form != real_form:
      if (case == "ins_sg" and "," in real_form and
          re.sub(",.*$", "", real_form) == pred_form):
        msg("For case ins_sg, predicted form %s has an alternate form not in actual form %s; allowed" % (pred_form, real_form))
      else:
        msg("For case %s, actual %s differs from predicted %s" % (case,
          real_form, pred_form))
        ok = False
  return ok

AC = u"\u0301"
GR = u"\u0300"
vowels_no_jo = u"аеиоуяэыюіѣѵАЕИОУЯЭЫЮІѢѴ"
vowels = vowels_no_jo + u"ёЁ"
sib_c = u"шщчжцШЩЧЖЦ"

def is_unstressed(word):
  return not re.search(ur"[ё" + AC + GR + "]", word)

def is_one_syllable(word):
  return len(re.sub("[^" + vowels + "]", "", word) == 1)

# assumes word is unstressed
def make_ending_stressed(word):
  word = re.sub("([" + vowels_no_jo + "])([^" + vowels_no_jo + "])*$",
      r"\1" + AC + r"\2", word)
  return word

def try_to_stress(word):
  if is_unstressed(word) and is_one_syllable(word):
    return make_ending_stressed(word)
  else:
    return word

def make_unstressed(word):
  word = word.replace(u"ё", u"е")
  word = word.replace(AC, "")
  word = word.replace(GR, "")
  return word

def add_soft_sign(stem):
  if re.match(".*[" + vowels + "]$", stem):
    return stem + u"й"
  else:
    return stem + u"ь"

def add_hard_neuter(stem):
  if re.match(".*[" + sib_c + "]$", stem):
    return stem + u"е"
  else:
    return stem + u"о"

def do_assert(cond, msg=None):
  if msg:
    assert cond, msg
  else:
    assert cond
  return True

def synthesize_singular(nompl, prepl, gender):
  soft = re.match(ur"^.*яхъ?$", prepl)
  m = re.match(ur"(.*)[аяыи]́?$", nompl)
  if not m:
    msg("WARNING: Strange nom plural %s" % nompl)
    return []
  stem = try_to_stress(m.group(1))
  if soft and gender == "f":
    return [add_soft_sign(stem), stem + u"я"]
  return [stem + u"а" if gender == "f" else
          add_soft_sign(stem) if soft and gender == "m" else
          stem if gender == "m" else
          stem + u"е" if soft and gender == "n" else
          add_hard_neuter(stem) if gender == "n" else
          do_assert(False, "Unrecognized gender: %s" % gender)]

def separate_multiwords(forms):
  words = []
  for case in forms:
    for multiform in re.split(r"\s+,\s+", forms[case]):
      formwords = re.split(r"\s+", multiform)
      for i in xrange(len(formwords)):
        if len(words) < i:
          words.append({})
      i = 0
      for word in formwords:
        if case in words[i]:
          words[i][case] += "," + word
        else:
          words[i][case] = word
        i += 1
  return words

def infer_decl(t, noungender):
  tname = unicode(t.name)
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
    number = ["n=pl"]
    numonly = "pl"
    getcases = ru_decl_noun_pl_cases
  else:
    assert False, "Unrecognized template name: %s" % tname

  i = 1
  for case in getcases:
    if case:
      form = getparam(t, i)
      if case == "pre_sg" or case == "pre_pl":
        form = re.sub(u"^о(б|бо)? ", "", form) # eliminate leading preposition
      forms[case] = form
    i += 1

  if " " in forms["nom_sg"]:
    msg("Unable to handle multi-word lemma: %s" % forms["nom_sg"])
    return None
  return infer_word(forms, number, numonly)

def infer_word(forms, number, numonly):
  nompl = forms["nom_pl"]
  gensg = forms["gen_sg"]
  genpl = try_to_stress(forms["gen_pl"])
  prepl = forms["pre_pl"]
  if numonly == "pl":
    nomsgs = synthesize_singular(nompl, prepl, noungender)
  else:
    nomsgs = [try_to_stress(forms["nom_sg"])]

  for nomsg in nomsgs:
    if numonly == "sg":
      if forms["acc_sg"] == forms["gen_sg"]:
        anim = ["a=an"]
      else:
        # Can't check for nom/acc sg equal because feminine nouns have all
        # three different
        anim = []
    else:
      if forms["acc_pl"] == forms["nom_pl"]:
        anim = []
      elif forms["acc_pl"] == forms["gen_pl"]:
        anim = ["a=an"]
      else:
        msg("WARNING: Unable to determine animacy: nom_pl=%s, acc_pl=%s, gen_pl=%s" %
            (forms["nom_pl"], forms["acc_pl"], forms["gen_pl"]))
        return None

    # FIXME: Adjectives in -ий of the +ьий type
    if (re.match(make_unstressed(nomsg), u"^.*([ыиіо]й|[яаь]я|[oeь]e)$") or
        numonly == "pl" and re.match(make_unstressed(nompl), u"^.*[ыи]e$")):
      args = ["", nomsg, "+"] + anim + number
      if trymatch(forms, args):
        msg("Found a match: {{ru-noun-table|%s}}" % "|".join(args))
        return args

    stress = "any"
    plstress = "any"
    genders = [""]
    bare = [""]
    m = re.match(ur"(.*)([аяеоё])(́?)$", nomsg)
    if m:
      msg("Nom sg %s refers to feminine 1st decl or neuter 2nd decl" % nomsg)
      stem = try_to_stress(m.group(1))
      ending = m.group(2)
      if m.group(3) or ending == u"ё":
        stress = "end"
      else:
        stress = "stem"

      if numonly != "sg":
        # Try to find a stressed version of the stem
        if is_unstressed(stem):
          mm = re.match(ur"(.*)[аяыи]́?$", nompl)
          if not mm:
            msg("WARNING: Don't recognize fem 1st-decl or neut 2nd-decl nom pl ending in form %s" % nompl)
          else:
            nomplstem = try_to_stress(mm.group(1))
            if make_unstressed(nomplstem) != stem:
              msg("Nom pl stem %s not accent-equiv to nom sg stem %s" % (
                nomplstem, stem))
            elif nomplstem != stem:
              msg("Replacing unstressed stem %s with stressed nom pl stem %s" %
                  (stem, nomplstem))
              stem = nomplstem

        if stem == genpl:
          msg("Gen pl %s same as stem" % genpl)
        elif make_unstressed(stem) != make_unstressed(genpl):
          msg("Stem %s not accent-equiv to gen pl %s" % (stem, genpl))
          bare = ["*", genpl]
        elif is_unstressed(stem):
          msg("Replacing unstressed stem %s with accent-equiv gen pl %s" %
              (stem, genpl))
          stem = genpl
        else:
          msg("Stem %s stressed one way, gen pl %s stressed differently" %
              (stem, genpl))
          bare = ["*", genpl]
      nomsg = stem + ending
    else:
      m = re.match(ur"(.*?)([йь]?)$", nomsg)
      if m:
        nomsgstem = m.group(1)
        ending = m.group(2)
        if numonly == "pl":
          if ending == u"ь":
            genders = [noungender]
        else:
          m = re.match(ur"(.*)([аяи])(́?)$", gensg)
          if not m:
            msg("WARNING: Don't recognize gen sg ending in form %s" % gensg)
            if ending == u"ь":
              genders = ["m", "f"]
          else:
            stem = try_to_stress(m.group(1))
            if ending == u"ь":
              if m.group(2) == u"я":
                msg("Found masculine soft-stem nom sg %s" % nomsg)
                genders = ["m"]
              else:
                msg("Found feminine soft-stem nom sg %s" % nomsg)
                genders = ["f"]
            elif ending == u"й":
              msg("Found masculine palatal-stem nom sg %s" % nomsg)
            else:
              msg("Found masculine consonant-stem nom sg %s" % nomsg)
            if m.group(3):
              stress = "end"
            else:
              stress = "stem"
            if stem == nomsgstem:
              msg("Nom sg stem %s same as stem" % nomsgstem)
            elif make_unstressed(stem) != make_unstressed(nomsgstem):
              msg("Stem %s not accent-equiv to nom sg stem %s" % (stem, nomsgstem))
              # If an element of BARE is a two-element list, the first is
              # the value of bare and the second is the value to use for the
              # first arg in place of nom sg.
              bare = ["*", [nomsg, stem + ending]]
            elif is_unstressed(stem):
              msg("Replacing unstressed stem %s with accent-equiv nom sg stem %s" %
                  (stem, nomsgstem))
            else:
              msg("Stem %s stressed one way, nom sg stem %s stressed differently" %
                  (stem, nomsgstem))
              # If an element of BARE is a two-element list, the first is
              # the value of bare and the second is the value to use for the
              # first arg in place of nom sg.
              bare = ["*", [nomsg, stem + ending]]

    # Find stress pattern possibilities
    if numonly != "sg":
      m = re.match(ur".*[аяыи](́?)$", nompl)
      if m:
        plstress = m.group(1) and "ending" or "stem"
    if numonly == "sg":
      plstress = "none"
    if numony == "pl":
      stress = "none"
    if stress == "any" or plstress == "any":
      msg("WARNING: Using all stress patterns")
      stress_patterns = all_stress_patterns
    else:
      stress_patterns = matching_stress_patterns[stress][plstress]

    for stress in stress_patterns:
      for gender in genders:
        for bareval in bare:
          # If bareval is a two-element list, the second is a value to
          # use for arg 1 in place of nomsg. See above.
          if type(bareval) is list:
            args = [stress, bareval[2], gender, bareval[1]]
          else:
            args = [stress, nomsg, gender, bareval]
          if not args[-1]:
            del args[-1]
          if not args[-1]:
            del args[-1]
          args += anim + number
          if trymatch(forms, args):
            msg("Found a match: {{ru-noun-table|%s}}" % "|".join(args))
            return args

    # I think these are always in -ов/-ев/-ин/-ын.
    #if re.match(nomsg, u"^.*([шщжчц]е|[ъоа]|)$"):
    if re.match(nomsg, u"^.*([ое]в|[ыи]н)([оаъ]?)$"):
      for adjpat in ["+short", "+mixed"]:
        args = ["", nomsg, adjpat] + anim + number
        if trymatch(forms, args):
          msg("Found a match: {{ru-noun-table|%s}}" % "|".join(args))
          return args

  msg("Unable to match: %s" % unicode(t))
  return None

def infer_one_page_decls(page, text):
  genders = set()
  for t in text.filter_tempates():
    if unicode(t.name) == "ru-noun":
      m = re.match("^([mfn])", getparam(t, "2"))
      if not m:
        msg("WARNING: Strange ru-noun template: %s" % unicode(t))
      else:
        genders.add(m.group(1))

  for t in text.filter_templates():
    if unicode(t.name) in ["ru-decl-noun", "ru-decl-noun-unc", "ru-decl-noun-pl"]:
      if unicode(t.name) == "ru-decl-noun-pl":
        genders = list(genders)
        if len(genders) == 0:
          msg("WARNING: Can't find gender for pl-only nominal %s" % unicode(page.title()))
          continue
        elif len(genders) > 1:
          msg("WARNING: Multiple genders found for pl-only nominal %s: %s" % (unicode(page.title()), genders))
          continue
        else:
          gender = genders[0]
      else:
        gender = ""
      args = infer_decl(t, gender)
      if args:
        for i in xrange(15, 0, -1):
          rmparam(t, i)
        t.name = "ru-noun-table"
        i = 1
        for arg in args:
          if "=" in arg:
            name, value = re.split("=", arg)
            t.add(name, value)
          else:
            t.add(i, arg)
            i += 1
  return text, "Infer declension for manual decls (ru-decl-noun)"

for page in blib.references("Template:ru-decl-noun"):
  blib.do_edit(page, infer_one_page_decls, save=save)
