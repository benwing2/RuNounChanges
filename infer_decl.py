#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import pywikibot
import mwparserfromhell

ru_decl_noun_cases = [
  "nom_sg", "gen_sg", "dat_sg", "acc_sg", "ins_sg", "pre_sg",
  "nom_pl", "gen_pl", "dat_pl", "acc_pl", "ins_pl", "pre_pl",
  "loc", None, "voc"]
all_cases = [x for x in ru_decl_noun_cases] + ["par"]

all_stress_patterns = ["1", "2", "3", "4", "5", "6", "4*", "6*"]
nom_sg_ending_stress_patterns = ["2", "4", "6", "4*", "6*"]
nom_sg_stem_stress_patterns = ["1", "3", "5"]

site = pywikibot.Site()

def msg(text):
  print text.encode('utf-8')

def parse(text):
  return mwparserfromhell.parser.Parser().parse(page.text, skip_style_tags=True))

def getparam(t, param):
  if t.has_param(param):
    return unicode(t.get(param))
  else:
    return ""

def try(forms, args):
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
      msg("For case %s, actual %s differs from predicted %s" % (case,
        real_form, pred_form))
  return ok

AC = u"\u0301"
GR = u"\u0300"
vowels_no_jo = "аеиоуяэыюіѣѵАЕИОУЯЭЫЮІѢѴ"
vowels = "аеиоуяэыюіѣѵАЕИОУЯЭЫЮІѢѴ" + "ёЁ"

def is_unstressed(word):
  return not re.search(ur"[ё" + AC + GR + "]", word)

def is_one_syllable(word):
  return len(re.sub("[^" + vowels + "]", "", word) == 1)

# assumes word is unstressed
def make_ending_stressed(word):
  word = re.sub("([" + vowels_no_jo + "])([^" + vowels_no_jo + "])*$",
      r"\1" + AC + r"\2", word)
  return word

def make_unstressed(word):
  word = word.replace(u"ё", u"е")
  word = word.replace(AC, "")
  word = word.replace(GR, "")
  return word

def infer_decl(t):
  forms = {}
  i = 1
  for case in ru_decl_noun_cases:
    if case:
      form = getparam(t, i)
      forms[case] = form
  
  nomsg = forms["nom_sg"]
  nompl = forms["nom_pl"]
  gensg = forms["gen_sg"]
  genpl = forms["gen_pl"]
  stress = "any"
  genders = [""]
  bare = ""
  m = re.match(ur"(.*)([аяеоё])(́?)$", nomsg)
  if m:
    msg("Nom sg %s refers to feminine 1st decl or neuter 2nd decl" % nomsg)
    stem = m.group(1)
    ending = m.group(2)
    if m.group(3) or ending == u"ё":
      stress = "end"
    else:
      stress = "stem"

    # Try to find a stressed version of the stem
    if is_unstressed(stem):
      if is_one_syllable(stem):
        stem = make_ending_stressed(stem)
      else:
        mm = re.match(ur"(.*)[аяыи]́?$", nompl)
        if not mm:
          msg("Don't recognize fem 1st-decl or neut 2nd-decl nom pl ending in form %s" % nompl)
        else:
          nomplstem = mm.group(1)
          if make_unstressed(nomplstem) != stem:
            msg("Nom pl stem %s not accent-equiv to nom sg stem %s" % (
              nomplstem, stem))
          elif nomplstem != stem:
            msg("Replacing unstressed stem %s with stressed nom pl stem %s" %
                (stem, nomplstem))
            stem = nomplstem

    if is_unstressed(genpl) and is_one_syllable(genpl):
      genpl = make_ending_stressed(genpl)
    if stem == genpl:
      msg("Gen pl %s same as stem" % genpl)
    elif make_unstressed(stem) != make_unstressed(genpl):
      msg("Stem %s not accent-equiv to gen pl %s" % (stem, genpl))
      bare = genpl
    elif is_unstressed(stem):
      msg("Replacing unstressed stem %s with accent-equiv gen pl %s" %
          (stem, genpl))
      stem = genpl
    else:
      msg("Stem %s stressed one way, gen pl %s stressed differently" %
          (stem, genpl))
      bare = genpl
    nomsg = stem + ending
  else:
    if is_unstressed(nomsg) and is_one_syllable(nomsg):
        nomsg = make_ending_stressed(nomsg)
    m = re.match(ur"(.*?)([йь]?)$", nomsg)
    if m:
      nomsgstem = m.group(1)
      ending = m.group(2)
      m = re.match(ur"(.*)([аяи])(́?)$", gensg)
      if not m:
        msg("Don't recognize gen sg ending in form %s" % gensg)
        if ending == u"ь":
          genders = ["m", "f"]
      else:
        stem = m.group(1)
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
        if is_unstressed(stem) and is_one_syllable(stem):
            stem = make_ending_stressed(stem)
        if stem == nomsgstem:
          msg("Nom sg stem %s same as stem" % nomsgstem)
        elif make_unstressed(stem) != make_unstressed(nomsgstem):
          msg("Stem %s not accent-equiv to nom sg stem %s" % (stem, nomsgstem))
          bare = nomsg
          nomsg = stem + ending
        elif is_unstressed(stem):
          msg("Replacing unstressed stem %s with accent-equiv nom sg stem %s" %
              (stem, nomsgstem))
        else:
          msg("Stem %s stressed one way, nom sg stem %s stressed differently" %
              (stem, nomsgstem))
          bare = nomsg
          nomsg = stem + ending

  stress_patterns = (stress == "end" and nom_sg_ending_stress_patterns or
      stress = "stem" and nom_sg_stem_stress_patterns or
      all_stress_patterns)

  for stress in stress_patterns:
    for gender in genders:
      args = [stress, nomsg, gender]
      if try(forms, args):
        msg("Found a match: {{ru-noun-table|%s}}" % "|".join(args))
        return args
  return None
