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

def infer_decl(t):
  forms = {}
  i = 1
  for case in ru_decl_noun_cases:
    if case:
      form = getparam(t, i)
      forms[case] = form
  
  nom_sg = forms["nom_sg"]
  stress = "any"
  genders = [""]
  if re.match(ur".*ь$", nom_sg):
    genders = ["m", "f"]
  elif re.match(ur".*ё$", nom_sg):
    stress = "end"
  else:
    m = re.match(ur"(.*[аяео])(́?)$", nom_sg)
    if m:
      nom_sg = m.group(1)
      if m.group(2):
        stress = "end"
      else:
        stress = "stem"
  stress_patterns = (stress == "end" and nom_sg_ending_stress_patterns or
      stress = "stem" and nom_sg_stem_stress_patterns or
      all_stress_patterns)

  for stress in stress_patterns:
    for gender in genders:
      args = [stress, nom_sg, gender]
      if try(forms, args):
        msg("Found a match: {{ru-noun-table|%s}}" % "|".join(args))
        return args
  return None
