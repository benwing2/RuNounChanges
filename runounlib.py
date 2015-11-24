#!/usr/bin/python
# -*- coding: utf-8 -*-

import re

import rulib as ru
import blib

def arg1_is_stress(arg1):
  if not arg1:
    return None
  for arg in re.split(",", arg1):
    if not (re.search("^[a-f]'?'?$", arg) or re.search(r"^[1-6]\*?$", arg)):
      return None
  return True

def try_to_stress(form):
  if "//" in form:
    m = re.search("^(.*?)//(.*)$", form)
    # FIXME: This should stress the translit as well
    return ru.try_to_stress(m.group(1)) + "//" + m.group(2)
  return ru.try_to_stress(form)

def check_old_noun_headword_forms(headword_template, args, subpagetitle, pagemsg):
  # FORM1 is the forms from ru-noun (or ru-proper noun); FORM2 is the combined
  # set of forms from ru-noun-table, and needs to be split on commas.
  # FORM1_LEMMA is true if the FORM1 values come from the ru-noun lemma.
  def compare_forms(case, form1, form2, form1_lemma=False):
    def fixup_link(f):
      m = re.search(r"^\[\[([^|]*?)\|([^|]*?)\]\]$", f)
      if m:
        lemma, infl = m.groups()
        # Make sure to remove accents, cf. [[десе́ртный|десе́ртное]]
        lemma = ru.remove_accents(re.sub("#Russian$", "", lemma))
        if ru.remove_accents(infl) == lemma:
          return "[[%s]]" % infl
        return "[[%s|%s]]" % (lemma, infl)
      return f
    # Split on individual words and allow monosyllabic accent differences.
    # FIXME: Will still have problems with [[X|Y]].
    def compare_single_form(f1, f2):
      pagemsg("Comparing f1=%s f2=%s" % (f1, f2))
      words1 = re.split("[ -]", f1)
      words2 = re.split("[ -]", f2)
      if len(words1) != len(words2):
        return None
      for i in xrange(len(words1)):
        pagemsg("Comparing words1=%s words2=%s" % (words1[i], words2[i]))
        if words1[i] != words2[i]:
          w1 = try_to_stress(fixup_link(words1[i]))
          w2 = words2[i]
          # Allow case where existing is missing a link as compared to
          # proposed (but not other way around; we don't want a link
          # disappearing)
          if w1 != w2 and w1 != blib.remove_links(w2):
            return None
      return True
    form1 = [fixup_link(re.sub(u"ё́", u"ё", x)) for x in form1]
    form2 = re.split(",", form2)
    if not form1_lemma:
      # Ignore manual translit in decl forms when comparing non-lemma forms;
      # not available from ru-noun (and not displayed anyway)
      form2 = [re.sub("//.*$", "", x) for x in form2]
    # If existing value missing, OK; also allow for unstressed monosyllabic
    # existing form matching stressed monosyllabic new form
    if form1:
      if (set(form1) == set(form2) or
          set(try_to_stress(x) for x in form1) == set(form2) or
          len(form1) == 1 and len(form2) == 1 and compare_single_form(form1[0], form2[0])):
        pass
      else:
        pagemsg("WARNING: case %s, existing forms %s not same as proposed %s" %(
            case, ",".join(form1), ",".join(form2)))
        return None
    return True

  def compare_genders(g1, g2):
    if set(g1) == set(g2):
      return True
    if len(g1) == 1 and len(g2) == 1:
      # If genders don't match exactly, check if existing gender is missing
      # animacy and allow that, so it gets overwritten with new gender
      if g1[0] == re.sub("-(an|in)", "", g2[0]):
        pagemsg("Existing gender %s missing animacy spec compared with proposed %s, allowed" % (
          ",".join(g1), ",".join(g2)))
        return True
    return None

  headwords = blib.process_arg_chain(headword_template, "1", "head", subpagetitle)
  translits = blib.process_arg_chain(headword_template, "tr", "tr")
  for i in xrange(len(translits)):
    if len(headwords) <= i:
      pagemsg("WARNING: Not enough headwords for translit tr%s=%s, skipping" % (
        "" if i == 0 else str(i+1), translits[i]))
      return None
    else:
      headwords[i] += "//" + translits[i]
  genitives = blib.process_arg_chain(headword_template, "3", "gen")
  plurals = blib.process_arg_chain(headword_template, "4", "pl")
  genders = blib.process_arg_chain(headword_template, "2", "g")
  cases_to_check = None
  if args["n"] == "s":
    if (not compare_forms("nom_sg", headwords, args["nom_sg_linked"], True) or
        not compare_forms("gen_sg", genitives, args["gen_sg"])):
      pagemsg("Existing and proposed forms not same, skipping")
      return None
    cases_to_check = ["nom_sg", "gen_sg"]
  elif args["n"] == "p":
    if (not compare_forms("nom_pl", headwords, args["nom_pl_linked"], True) or
        not compare_forms("gen_pl", genitives, args["gen_pl"])):
      pagemsg("Existing and proposed forms not same, skipping")
      return None
    cases_to_check = ["nom_pl", "gen_pl"]
  elif args["n"] == "b":
    if (not compare_forms("nom_sg", headwords, args["nom_sg_linked"], True) or
        not compare_forms("gen_sg", genitives, args["gen_sg"]) or
        not compare_forms("nom_pl", plurals, args["nom_pl"])):
      pagemsg("Existing and proposed forms not same, skipping")
      return None
    cases_to_check = ["nom_sg", "gen_sg", "nom_pl"]
  else:
    pagemsg("WARNING: Unrecognized number spec %s, skipping" % args["n"])
    return None

  for case in cases_to_check:
    raw_case = re.sub(u"△", "", blib.remove_links(args[case + "_raw"]))
    if args[case] != raw_case:
      pagemsg("WARNING: Raw case %s contains footnote symbol" % args[case + "_raw"])

  proposed_genders = re.split(",", args["g"])
  if compare_genders(genders, proposed_genders):
    genders = []
  else:
    # Check for animacy mismatch, punt if so
    cur_in = [x for x in genders if re.search(r"\bin\b", x)]
    cur_an = [x for x in genders if re.search(r"\ban\b", x)]
    proposed_in = [x for x in proposed_genders if re.search(r"\bin\b", x)]
    proposed_an = [x for x in proposed_genders if re.search(r"\ban\b", x)]
    if (cur_in or not cur_an) and proposed_an or (cur_an or not cur_in) and proposed_in:
      pagemsg("WARNING: Animacy mismatch, skipping: cur=%s proposed=%s" % (
        ",".join(genders), ",".join(proposed_genders)))
      return None
    # Check for number mismatch, punt if so
    cur_pl = [x for x in genders if re.search(r"\bp\b", x)]
    if cur_pl and args["n"] != "p" or not cur_pl and args["n"] == "p":
      pagemsg("WARNING: Number mismatch, skipping: cur=%s, proposed=%s, n=%s" % (
        ",".join(genders), ",".join(proposed_genders), args["n"]))
      return None
    pagemsg("WARNING: Gender mismatch, existing=%s, new=%s" % (
      ",".join(genders), ",".join(proposed_genders)))

  return genders

def fix_old_headword_params(headword_template, new_params, genders, pagemsg):

  for param in headword_template.params:
    name = unicode(param.name)
    if name not in ["1", "2", "3", "4"] and re.search(r"^[0-9]+$", name):
      pagemsg("WARNING: Extraneous numbered param %s=%s in headword template, skipping" % (
        unicode(param.name), unicode(param.value)))
      return None

  params_to_preserve = []
  for param in headword_template.params:
    name = unicode(param.name)
    if (name not in ["1", "2", "3", "4", "g", "gen", "pl", "tr"] and
        not re.search(r"^(head|g|gen|pl|tr)[0-9]+$", name)):
      params_to_preserve.append(param)

  del headword_template.params[:]
  for name, value in new_params:
    headword_template.add(name, value)
  i = 1
  for g in genders:
    headword_template.add("g" if i == 1 else "g%s" % i, g)

  return params_to_preserve
