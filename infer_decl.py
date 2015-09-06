#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import traceback, sys
import pywikibot
import mwparserfromhell
import blib
from blib import msg, rmparam, getparam

from rulib import *

save = False
mockup = False
# Uncomment the following line to enable test mode
mockup = True
# If true, use the old ru-noun-table template, instead of new
# ru-decl-noun-new
old_template = False

if old_template:
  decl_template = "ru-noun-table"
else:
  decl_template = "ru-decl-noun-new"

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
matching_stress_patterns["stem"]["stem"] = {"by":"pre_pl", "stem":"1", "ending":"5"}
matching_stress_patterns["stem"]["ending"] = ["3"]
matching_stress_patterns["ending"]["stem"] = {
  "by":"pre_pl",
  "ending":{"by":"acc_sg", "ending":"4", "stem":"4*"},
  "stem":{"by":"acc_sg", "ending":"6", "stem":"6*"},
}
matching_stress_patterns["ending"]["ending"] = ["2"]
matching_stress_patterns["stem"]["none"] = ["1"]
matching_stress_patterns["ending"]["none"] = {"by":"acc_sg", "ending":"2", "stem":"6*"}
matching_stress_patterns["none"]["stem"] = {"by":"pre_pl", "stem":"1", "ending":"5"}
matching_stress_patterns["none"]["ending"] = ["2"]

site = pywikibot.Site()

def trymatch(forms, args, pagemsg, output_msg=True):
  if mockup:
    ok = True
  else:
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
        pagemsg("Missing actual form for case %s (predicted %s)" % (case, pred_form))
        ok = False
      elif real_form and not pred_form:
        pagemsg("Actual has extra form %s=%s not in predicted" % (case, real_form))
        ok = False
      elif pred_form != real_form:
        if is_unstressed(real_form) and make_unstressed(pred_form) == real_form:
          # Happens especially in monosyllabic forms
          pagemsg("For case %s, actual form %s missing an accent that's present in predicted %s; allowed" % (real_form, pred_form))
        elif (case == "ins_sg" and "," in real_form and
            re.sub(",.*$", "", real_form) == pred_form):
          pagemsg("For case ins_sg, predicted form %s has an alternate form not in actual form %s; allowed" % (pred_form, real_form))
        else:
          pagemsg("For case %s, actual %s differs from predicted %s" % (case,
            real_form, pred_form))
          ok = False
  if ok:
    pagemsg("Found a match: {{%s|%s}}" % (decl_template, "|".join(args)))
  return ok

def synthesize_singular(nompl, prepl, gender, pagemsg):
  m = re.search(ur"^(.*)([ыи])(́?)е$", nompl)
  if m:
    stem = m.group(1)
    ty = (re.search(u"[кгx]$", stem) and "velar" or
          re.search(u"[шщжч]$", stem) and "sibilant" or
          re.search(u"ц$", stem) and "c" or
          m.group(2) == u"и" and "soft" or
          "hard")
    ac = m.group(3)
    if ac:
      sg = (stem + u"о́й" if gender == "m" else
          stem + u"а́я" if gender == "f" else stem + u"о́е")
    elif ty == "soft":
      sg = (stem + u"ий" if gender == "m" else
          stem + u"яя" if gender == "f" else stem + u"ее")
    elif ty == "velar" or ty == "sibilant":
      sg = (stem + u"ий" if gender == "m" else
          stem + u"ая" if gender == "f" else stem + u"ое")
    elif ty == "c":
      sg = (stem + u"ый" if gender == "m" else
          stem + u"ая" if gender == "f" else stem + u"ее")
    else:
      sg = (stem + u"ый" if gender == "m" else
          stem + u"ая" if gender == "f" else stem + u"ое")
    return [sg]

  m = re.search(ur"^(.*)[аяыи]́?$", nompl)
  if not m:
    pagemsg("WARNING: Strange nom plural %s" % nompl)
    return []
  stem = try_to_stress(m.group(1))
  soft = re.search(ur"яхъ?$", prepl)
  if soft and gender == "f":
    return [add_soft_sign(stem), stem + u"я"]
  return [stem + u"а" if gender == "f" else
          add_soft_sign(stem) if soft and gender == "m" else
          stem if gender == "m" else
          stem + u"е" if soft and gender == "n" else
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
  return words

def infer_decl(t, noungender, pagemsg):
  tname = unicode(t.name).strip()
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
      form = getparam(t, i).strip()
      form = remove_links(form)
      if case == "pre_sg" or case == "pre_pl":
        # eliminate leading preposition
        form = re.sub(ur"^о(б|бо)?\s+", "", form)
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
          args = infer_word(wordforms, noungender, number, numonly, pagemsg)
          if not args:
            pagemsg("Unable to infer word #%s: %s" % (wordno, unicode(t)))
            return None
          argses.append(args)
        animacies = [x for args in argses for x in args if x in ["a=in", "a=an"]]
        if "a=in" in animacies and "a=an" in animacies:
          pagemsg("WARNING: Conflicting animacies in multi-word expression: %s" %
              unicode(t))
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
              allargs.append(old_template and "join:-" or "-")
            elif old_template:
              allargs.append("_")
          allargs.extend(filterargs)
        allargs += animacy + number
        pagemsg("Found a multi-word match: {{%s|%s}}" % (decl_template, "|".join(allargs)))
        return allargs
    else:
      args = infer_word(forms, noungender, number, numonly, pagemsg)
      return [x for x in args if x != "a=in"]
  for ty in ["space", "dash", "single"]:
    args = try_multiword(ty)
    if args:
      return args

def generate_template_args(stress, nomsg, gender, bareval, pagemsg):
  if old_template:
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
  else:
    gender = gender and "*" + gender or ""
    if type(bareval) is list:
      arg1 = bareval[2]
      bareval = bareval[1]
    else:
      # At this point if stress pattern is 2, move the
      # stress onto the ending if nomsg is fem. or neut. and
      # the stress can be recovered in the gen pl.
      if stress == "2":
        m = re.search("^(.*[" + vowels_no_jo + "]" + AC + "?[^" + vowels + u"]*)([аяео])$", nomsg)
        if m and u"ё" not in m.group(1):
          newnomsg = make_unstressed(m.group(1)) + m.group(2) + AC
          pagemsg("Accent-class 2 fem 1st or neut, moving stress onto ending from %s to %s" % (nomsg, newnomsg))
          nomsg = newnomsg
      if is_unstressed(nomsg):
        pagemsg("WARNING: Arg 1 (stem/nom-sg) %s is totally unstressed" % (nomsg))
        # FIXME: If it's one syllable, should we stress it?
        # Does this ever happen? We try hard to stress monosyllabic
        # stems up above.
      arg1 = nomsg

    if re.search(u"[ё́]$", arg1):
      defstress = "2"
    else:
      defstress = "1"
    if defstress == stress:
      stress = ""
    args = [arg1 + gender, stress, bareval]
    if not args[-1]:
      del args[-1]
    if not args[-1]:
      del args[-1]
    args = [":".join(args)]
  return args

def infer_word(forms, noungender, number, numonly, pagemsg):
  # Check for invariable word
  caseforms = forms.values()
  allsame = True
  for caseform in caseforms[1:]:
    if caseform != caseforms[0]:
      allsame = False
      break
  if allsame:
    pagemsg("Found invariable word %s" % caseforms[0])
    if old_template:
      return ["", caseforms[0], "*"]
    else:
      return [caseforms[0] + "*"]

  nompl = forms.get("nom_pl", "")
  accsg = forms.get("acc_sg", "")
  accsg_stress = re.search(u"[ё́]$", accsg) and "ending" or "stem"
  gensg = forms.get("gen_sg", "")
  genpl = try_to_stress(forms.get("gen_pl", ""))
  presg = forms.get("pre_sg", "")
  prepl = forms.get("pre_pl", "")
  prepl_stress = re.search(AC + u"хъ?$", prepl) and "ending" or "stem"

  # Special case:
  if numonly == "pl" and nompl == u"острова́":
    args = generate_template_args("3", u"о́стров", "", "", pagemsg) + number
    if trymatch(forms, args, pagemsg):
      return args

  if numonly == "pl":
    nomsgs = synthesize_singular(nompl, prepl, noungender, pagemsg)
  else:
    nomsgs = [try_to_stress(forms["nom_sg"])]

  for nomsg in nomsgs:
    if numonly == "sg":
      if forms["acc_sg"] == forms["gen_sg"]:
        anim = ["a=an"]
      elif forms["acc_sg"] == forms["nom_sg"]:
        anim = ["a=in"]
      else:
        # Can't check for nom/acc sg equal because feminine nouns have all
        # three different
        anim = []
    else:
      if forms["acc_pl"] == forms["nom_pl"]:
        anim = ["a=in"]
      elif forms["acc_pl"] == forms["gen_pl"]:
        anim = ["a=an"]
      else:
        pagemsg("WARNING: Unable to determine animacy: nom_pl=%s, acc_pl=%s, gen_pl=%s" %
            (forms["nom_pl"], forms["acc_pl"], forms["gen_pl"]))
        return None

    # Adjectives in -ий of the +ьий type, special because they
    # can't be auto-detected
    if re.search(u"ий$", nomsg) and re.search(u"ьего$", gensg):
      stem = re.sub(u"ий$", "", nomsg)
      if old_template:
        args = ["", stem, "+ьий"] + anim + number
      else:
        args = [stem + "+ьий"] + anim + number
      if trymatch(forms, args, pagemsg):
        return args

    def adj_by_prep():
      return (
        numonly == "sg" and re.search(u"[ое][мй]$", make_unstressed(presg)) or
        numonly != "sg" and re.search(u"[ыи]х$", make_unstressed(prepl)))

    if (re.search(u"([ыиіо]й|[яаь]я|[оеь]е)$", make_unstressed(nomsg)) and
        adj_by_prep()):
      if old_template:
        args = ["", nomsg, "+"] + anim + number
      else:
        args = [nomsg + "+"] + anim + number
      if trymatch(forms, args, pagemsg):
        return args

    # I think these are always in -ов/-ев/-ёв/-ин/-ын.
    #if re.search(u"([шщжчц]е|[ъоа]|)$", nomsg):
    if (re.search(u"([ое]в|[ыи]н)([оаъ]?)$", make_unstressed(nomsg)) and
        adj_by_prep()):
      for adjpat in ["+short", "+mixed"]:
        if old_template:
          args = ["", nomsg, adjpat] + anim + number
        else:
          args = [nomsg + adjpat] + anim + number
        if trymatch(forms, args, pagemsg):
          return args

    # Ending in -мя, nom pl in either -мена́ or -мёна.
    if re.search(u"мя$", nomsg):
      args = None
      if numonly == "sg" or re.search(u"мена́$", nompl):
        if old_template:
          args = ["3", nomsg]
        else:
          args = [nomsg + ":3"]
      elif rsearch(u"мёна$", nompl):
        stem = re.sub(u"мя$", "", nomsg)
        if old_template:
          args = ["3", stem, u"мя-1"]
        else:
          args = [stem + "*мя-1:3"]
      if args:
        args += anim + number
        if trymatch(forms, args, pagemsg):
          return args

    stress = "any"
    plstress = "any"
    genders = [""]
    bare = [""]
    strange_plural = ""

    ########## Check for feminine or neuter
    m = re.search(ur"^(.*)([аяеоё])(́?)$", nomsg)
    if m:
      pagemsg("Nom sg %s refers to feminine 1st decl or neuter 2nd decl" % nomsg)
      # We use to call try_to_stress() here on the stem but that fails if
      # the stem has е and we stress it as е́ when it should be ё
      stem = m.group(1)
      ending = m.group(2)
      if m.group(3) or ending == u"ё":
        stress = "ending"
      else:
        stress = "stem"

      for numrestrict, regex, formcase in [
          ("sg", ur"^(.*)[аяыи]́?$", "nom_pl"), # accent patterns 4, 6
          ("pl", ur"^(.*)[уюоеё]́?$", "acc_sg"), # accent patterns 4*, 6* 
          ("sg", ur"^(.*)([ая]́?х)$", "pre_pl"), # necessary???
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
              if make_unstressed(formstem) != stem:
                pagemsg("%s stem %s not accent-equiv to nom sg stem %s" % (
                  formcase, formstem, stem))
              elif formstem != stem:
                pagemsg("Replacing unstressed stem %s with stressed %s stem %s" %
                    (stem, formcase, formstem))
                stem = formstem

      # Look at gen pl to check for reducible and try to get a stressed stem;
      # also check for strange plurals
      if numonly != "sg":
        ustem = make_unstressed(stem)
        unompl = make_unstressed(nompl)
        mm = re.search("^" + ustem + u"(ья|[иы])$", unompl)
        if mm:
          strange_plural = "-" + mm.group(1)
          # Not a strange plural if feminine with expected plural
          if ending in [u"а", u"я"] and strange_plural in [u"-ы", u"-и"]:
            strange_plural = ""
        if strange_plural:
          pagemsg("Found unusual plural %s" % strange_plural)

        # Don't check gen pl if we found strange plural, because it won't
        # be a bare stem.
        if not strange_plural:
          possible_genpls = []
          possible_unstressed_genpls = []
          for genpl_ending in ["", u"ь", u"й"]:
            possible_genpls.append(stem + genpl_ending)
            possible_unstressed_genpls.append(make_unstressed(stem + genpl_ending))
          if genpl in possible_genpls:
            pagemsg("Gen pl %s same as stem %s (modulo expected endings)" % (genpl, stem))
          elif make_unstressed(genpl) not in possible_unstressed_genpls:
            pagemsg("Stem %s not accent-equiv to gen pl %s (modulo expected endings)" % (stem, genpl))
            bare = ["*", genpl]
          elif is_unstressed(stem):
            pagemsg("Replacing unstressed stem %s with accent-equiv gen pl %s" %
                (stem, genpl))
            stem = re.sub(u"[ьй]$", "", genpl)
          else:
            pagemsg("Stem %s stressed one way, gen pl %s stressed differently" %
                (stem, genpl))
            bare = ["*", genpl]

      # Auto-stress monosyllabic stem if necessary
      if is_unstressed(stem) and is_unstressed(ending):
        trystress = try_to_stress(stem)
        if trystress != stem:
          pagemsg("Replacing monosyllabic unstressed stem %s with stressed equiv %s" % (stem, trystress))
          stem = trystress

      nomsg = stem + ending

    ########## Check for masculine
    else:
      m = re.search(ur"^(.*?)([йь]?)$", nomsg)
      if m:
        nomsgstem = m.group(1)
        ending = m.group(2)
        stem = nomsgstem
        if numonly == "pl":
          if ending == u"ь":
            genders = [noungender]
        else:
          m = re.search(ur"^(.*)([аяи])(́?)$", gensg)
          if not m:
            pagemsg("WARNING: Don't recognize gen sg ending in form %s" % gensg)
            if ending == u"ь":
              genders = ["m", "f"]
          else:
            # We use to call try_to_stress() here on the stem but that fails if
            # the stem has е and we stress it as е́ when it should be ё
            stem = m.group(1)
            # Try to find a stressed version of the stem
            if is_unstressed(stem):
              mm = re.search(ur"^(.*)[аяыи]́?$", nompl)
              if not mm:
                pagemsg("WARNING: Don't recognize nom pl ending in form %s" % nompl)
              else:
                nomplstem = mm.group(1)
                if make_unstressed(nomplstem) != stem:
                  pagemsg("Nom pl stem %s not accent-equiv to gen sg stem %s" % (
                    nomplstem, stem))
                elif nomplstem != stem:
                  pagemsg("Replacing unstressed stem %s with stressed nom pl stem %s" %
                      (stem, nomplstem))
                  stem = nomplstem
            if ending == u"ь":
              if m.group(2) == u"я":
                pagemsg("Found masculine soft-stem nom sg %s" % nomsg)
                genders = ["m"]
              else:
                pagemsg("Found feminine soft-stem nom sg %s" % nomsg)
                genders = ["f"]
            elif ending == u"й":
              pagemsg("Found masculine palatal-stem nom sg %s" % nomsg)
            else:
              pagemsg("Found masculine consonant-stem nom sg %s" % nomsg)
            if m.group(3):
              stress = "ending"
            else:
              stress = "stem"
            if stem == nomsgstem:
              pagemsg("Nom sg stem %s same as stem" % nomsgstem)
            elif make_unstressed(stem) != make_unstressed(nomsgstem):
              pagemsg("Stem %s not accent-equiv to nom sg stem %s" % (stem, nomsgstem))
              # If an element of BARE is a two-element list, the first is
              # the value of bare and the second is the value to use for the
              # first arg in place of nom sg.
              bare = ["*", [nomsg, try_to_stress(stem + ending)]]
            elif is_unstressed(stem):
              pagemsg("Replacing unstressed stem %s with accent-equiv nom sg stem %s" %
                  (stem, nomsgstem))
            else:
              pagemsg("Stem %s stressed one way, nom sg stem %s stressed differently" %
                  (stem, nomsgstem))
              # If an element of BARE is a two-element list, the first is
              # the value of bare and the second is the value to use for the
              # first arg in place of nom sg.
              bare = ["*", [nomsg, try_to_stress(stem + ending)]]

        # Check for strange plural
        if numonly != "sg":
          ustem = make_unstressed(stem)
          unompl = make_unstressed(nompl)
          mm = re.search("^" + ustem + u"(ья|а)$", unompl)
          if mm:
            strange_plural = "-" + mm.group(1)
            pagemsg("Found unusual plural %s" % strange_plural)

    # Find stress pattern possibilities
    if numonly != "sg":
      m = re.search(ur"[аяыи](́?)$", nompl)
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

    for stress in stress_patterns:
      for gender in genders:
        for bareval in bare:
          args = generate_template_args(stress, nomsg, gender + strange_plural,
              bareval, pagemsg)
          args += anim + number
          if trymatch(forms, args, pagemsg):
            return args

  return None

def infer_one_page_decls_1(page, index, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, unicode(page.title()), txt))
  genders = set()
  for t in text.filter_templates():
    if unicode(t.name).strip() in ["ru-noun", "ru-proper noun"]:
      m = re.search("^([mfn])", getparam(t, "2"))
      if not m:
        pagemsg("WARNING: Strange ru-noun template: %s" % unicode(t))
      else:
        genders.add(m.group(1))

  for t in text.filter_templates():
    if unicode(t.name).strip() in ["ru-decl-noun", "ru-decl-noun-unc", "ru-decl-noun-pl"]:
      if unicode(t.name).strip() == "ru-decl-noun-pl":
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
      args = infer_decl(t, gender, pagemsg)
      if args:
        for i in xrange(15, 0, -1):
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
  return text, "Infer declension for manual decls (ru-decl-noun)"

def infer_one_page_decls(page, index, text):
  try:
    return infer_one_page_decls_1(page, index, text)
  except StandardError as e:
    msg("%s %s: WARNING: Got an error: %s" % (index, unicode(page.title()), repr(e)))
    traceback.print_exc(file=sys.stdout)
    return text, "no change"

def iter_pages(iterator):
  i = 0
  for page in iterator:
    i += 1
    yield page, i

test_templates = [
  u"""{{ru-decl-noun
    |сре́дний па́лец|сре́дние па́льцы
    |сре́днего па́льца|сре́дних па́льцев
    |сре́днему па́льцу|сре́дним па́льцам
    |сре́дний па́лец|сре́дние па́льцы
    |сре́дним па́льцем|сре́дними па́льцами
    |о сре́днем па́льце|о сре́дних па́льцах}}""",
  u"""{{ru-decl-noun
    |лист Мёбиуса|листы́ Мёбиуса
    |листа́ Мёбиуса|листо́в Мёбиуса
    |листу́ Мёбиуса|листа́м Мёбиуса
    |лист Мёбиуса|листы́ Мёбиуса
    |листо́м Мёбиуса|листа́ми Мёбиуса
    |о листе́ Мёбиуса|о листа́х Мёбиуса}}""",
  u"""{{ru-decl-noun|ма́льчик для битья́|ма́льчики для битья́|ма́льчика для битья́|ма́льчиков для битья́|ма́льчику для битья́|ма́льчикам для битья́|ма́льчика для битья́|ма́льчиков для битья́|ма́льчиком для битья́|ма́льчиками для битья́|о ма́льчике для битья́|о ма́льчиках для битья́}}""",
  u"""{{ru-decl-noun
  |ба́бье ле́то|ба́бьи лета́
  |ба́бьего ле́та|ба́бьих лет
  |ба́бьему ле́ту|ба́бьим лета́м
  |ба́бье ле́то|ба́бьи лета́
  |ба́бьим ле́том|ба́бьими лета́ми
  |о ба́бьем ле́те|о ба́бьих лета́х}}""",
  u"""{{ru-decl-noun
  |часть ре́чи|ча́сти ре́чи
  |ча́сти ре́чи|часте́й ре́чи
  |ча́сти ре́чи|частя́м ре́чи
  |часть ре́чи|ча́сти ре́чи
  |ча́стью ре́чи|частя́ми ре́чи
  |о ча́сти ре́чи|о частя́х ре́чи}}""",
  u"""{{ru-decl-noun
  |де́тская|де́тские
  |де́тской|де́тских
  |де́тской|де́тским
  |де́тскую|де́тские
  |де́тской|де́тскими
  |о де́тской|о де́тских}}""",
  u"""{{ru-decl-noun|медоно́сная пчела́|медоно́сные пчёлы|медоно́сной пчелы́|медоно́сных пчёл|медоно́сной пчеле́|медоно́сным пчёлам|медоно́сную пчелу́|медоно́сных пчёл|медоно́сной пчело́й|медоно́сными пчёлами|о медоно́сном пчеле́|о медоно́сных пчёлах}}""",
  u"""{{ru-decl-noun
  |истреби́тель-бомбардиро́вщик|истреби́тели-бомбардиро́вщики
  |истреби́теля-бомбардиро́вщика|истреби́телей-бомбардиро́вщиков
  |истреби́телю-бомбардиро́вщику|истреби́телям-бомбардиро́вщикам
  |истреби́тель-бомбардиро́вщик|истреби́тели-бомбардиро́вщики
  |истреби́телем-бомбардиро́вщиком|истреби́телями-бомбардиро́вщиками
  |об истреби́теле-бомбардиро́вщике|об истреби́телях-бомбардиро́вщиках}}""",
  u"""{{ru-decl-noun
  |ко́свенный паде́ж|ко́свенные падежи́
  |ко́свенного падежа́|ко́свенных падеже́й
  |ко́свенному падежу́|ко́свенным падежа́м
  |ко́свенный паде́ж|ко́свенные падежи́
  |ко́свенным падежо́м|ко́свенными падежа́ми
  |о ко́свенном падеже́|о ко́свенных падежа́х}}""",
  u"""{{ru-decl-noun
  |кусо́к дерьма́|куски́ дерьма́
  |куска́ дерьма́|куско́в дерьма́
  |куску́ дерьма́|куска́м дерьма́
  |кусо́к дерьма́|куски́ дерьма́
  |куско́м дерьма́|куска́ми дерьма́
  |о куске́ дерьма́|о куска́х дерьма́}}""",
  u"""{{ru-decl-noun
  |противота́нковый ёж|противота́нковые ежи́
  |противота́нкового ежа́|противота́нковых еже́й
  |противота́нковому ежу́|противота́нковым ежа́м
  |противота́нковый ёж|противота́нковые ежи́
  |противота́нковым ежо́м|противота́нковыми ежа́ми
  |о противота́нковом еже́|о против.ота́нковых ежа́х}}""",
  u"""{{ru-decl-noun
  |а́рмия Соединённых Шта́тов Аме́рики|а́рмии Соединённых Шта́тов Аме́рики
  |а́рмии Соединённых Шта́тов Аме́рики|а́рмий Соединённых Шта́тов Аме́рики
  |а́рмии Соединённых Шта́тов Аме́рики|а́рмиям Соединённых Шта́тов Аме́рики
  |а́рмию Соединённых Шта́тов Аме́рики|а́рмии Соединённых Шта́тов Аме́рики
  |а́рмией Соединённых Шта́тов Аме́рики|а́рмиями Соединённых Шта́тов Аме́рики
  |об а́рмии Соединённых Шта́тов Аме́рики|об а́рмиях Соединённых Шта́тов Аме́рики}}""",
  u"""{{ru-decl-noun
  |дезоксирибонуклеи́новая кислота́|дезоксирибонуклеи́новые кисло́ты
  |дезоксирибонуклеи́новой кислоты́|дезоксирибонуклеи́новых кисло́т
  |дезоксирибонуклеи́новой кислоте́|дезоксирибонуклеи́новым кисло́там
  |дезоксирибонуклеи́новую кислоту́|дезоксирибонуклеи́новые кисло́ты
  |дезоксирибонуклеи́новой кислото́й|дезоксирибонуклеи́новыми кисло́тами
  |о дезоксирибонуклеи́новой кислоте́|о дезоксирибонуклеи́новых кисло́тах}}""",
  u"""{{ru-decl-noun
  |Ба́ба-Яга́|Ба́бы-Яги́
  |Ба́бы-Яги́|Баб-Яг
  |Ба́бе-Яге́|Ба́бам-Яга́м
  |Ба́бу-Ягу́|Баб-Яг
  |Ба́бой-Яго́й|Ба́бами-Яга́ми
  |о Ба́бе-Яге́|о Ба́бах-Яга́х}}""",
  u"""{{ru-decl-noun
  |кори́чное де́рево|кори́чные дере́вья
  |кори́чного де́рева|кори́чных дере́вьев
  |кори́чному де́реву|кори́чным дере́вьям
  |кори́чное де́рево|кори́чные дере́вья
  |кори́чным де́ревом|кори́чными дере́вьями
  |о кори́чном де́реве|о кори́чных дере́вьях}}""",
  u"""{{ru-decl-noun
  |щётка для ресни́ц|щётки для ресни́ц
  |щётки для ресни́ц|щёток для ресни́ц
  |щётке для ресни́ц|щёткам для ресни́ц
  |щётку для ресни́ц|щётки для ресни́ц
  |щёткой для ресни́ц|щётками для ресни́ц
  |о щётке для ресни́ц|о щётках для ресни́ц}}""",
  u"""{{ru-decl-noun
  |учи́тель|учителя́, учители́
  |учи́теля|учителе́й
  |учи́телю|учителя́м
  |учи́теля|учителе́й
  |учи́телем|учителя́ми
  |учи́теле|учителя́х
  }}""",
  u"""{{ru-decl-noun
  |пе́рвое лицо́|пе́рвые ли́ца
  |пе́рвого лица́|пе́рвых лиц
  |пе́рвому лицу́|пе́рвым ли́цам
  |пе́рвое лицо́|пе́рвые ли́ца
  |пе́рвым лицо́м|пе́рвыми ли́цами
  |о пе́рвом лице́|о пе́рвых ли́цах}}""",
  u"""{{ru-decl-noun
  |тре́тье лицо́|тре́тьи ли́ца
  |тре́тьего лица́|тре́тьих лиц
  |тре́тьему лицу́|тре́тьим ли́цам
  |тре́тье лицо́|тре́тьи ли́ца
  |тре́тьим лицо́м|тре́тьими ли́цами
  |о тре́тьем лице́|о тре́тьих ли́цах}}""",
  u"""====Declension====
  {{ru-decl-noun
  |отглаго́льное существи́тельное|отглаго́льные существи́тельные
  |отглаго́льного существи́тельного|отглаго́льных существи́тельных
  |отглаго́льному существи́тельному|отглаго́льным существи́тельным
  |отглаго́льное существи́тельное|отглаго́льные существи́тельные
  |отглаго́льным существи́тельным|отглаго́льными существи́тельными
  |об отглаго́льном существи́тельном|об отглаго́льных существи́тельных}}""",
  u"""{{ru-decl-noun
  |кра́сное смеще́ние|кра́сные смеще́ния
  |кра́сного смеще́ния|кра́сных смеще́ний
  |кра́сному смеще́нию|кра́сным смеще́ниям
  |кра́сное смеще́ние|кра́сные смеще́ния
  |кра́сным смеще́нием|кра́сными смеще́ниями
  |о кра́сном смеще́нии|о кра́сных смеще́ниях}}""",
  u"""{{ru-decl-noun
  |кардина́льное число́|кардина́льные чи́сла
  |кардина́льного числа́|кардина́льных чи́сел
  |кардина́льному числу́|кардина́льным чи́слам
  |кардина́льное число́|кардина́льные чи́сла
  |кардина́льным число́м|кардина́льными чи́слами
  |о кардина́льном числе́|о кардина́льных чи́слах}}""",
  u"""{{ru-decl-noun
  |страна́ све́та|стра́ны све́та
  |страны́ све́та|стран све́та
  |стране́ све́та|стра́нам све́та
  |страну́ све́та|стра́ны све́та
  |страно́й све́та|стра́нами све́та
  |о стране́ све́та|о стра́нах све́та}}""",
  u"""{{ru-decl-noun
  |и́мя числи́тельное|имена́ числи́тельные
  |и́мени числи́тельного|имён числи́тельных
  |и́мени числи́тельному|имена́м числи́тельным
  |и́мя числи́тельное|имена́ числи́тельные
  |и́менем числи́тельным|имена́ми числи́тельными
  |об и́мени числи́тельном|об имена́х числи́тельных}}""",
  u"""{{ru-decl-noun
  |мужско́й полово́й член|мужски́е половы́е чле́ны
  |мужско́го полово́го чле́на|мужски́х половы́х чле́нов
  |мужско́му полово́му чле́ну|мужски́м половы́м чле́нам
  |мужско́й полово́й член|мужски́е половы́е чле́ны
  |мужски́м половы́м ч.ле́ном|мужски́ми половы́ми чле́нами
  |мужско́м полово́м чле́не|мужски́х половы́х чле́нах}}""",
  u"""{{ru-decl-noun
  |варёное яйцо́|варёные я́йца
  |варёного яйца́|варёных яи́ц
  |варёному яйцу́|варёным я́йцам
  |варёное яйцо́|варёные я́йца
  |варёным яйцо́м|варёными я́йцами
  |о варёном яйце́|о варёных я́йцах}}""",
  u"""{{ru-decl-noun
  |коренно́й зуб|коренны́е зу́бы
  |коренно́го зу́ба|коренны́х зубо́в
  |коренно́му зу́бу|коренны́м зуба́м
  |коренно́й зуб|коренны́е зу́бы
  |коренны́м зу́бом|коренны́ми зуба́ми
  |о коренно́м зу́бе|о коренны́х зуба́х}}""",
  u"""{{ru-decl-noun
  |зени́тный пулемёт|зени́тные пулемёты
  |зени́тного пулемёта|зени́тных пулемётов
  |зени́тному пулемёту|зени́тным пулемётам
  |зени́тный пулемёт|зени́тные пулемёты
  |зени́тным пулемётом|зени́тными пулемётами
  |о зени́тном пулемёте|о зени́тных пулемётах}}""",
  u"""{{ru-decl-noun
  |вре́мя го́да|времена́ го́да
  |вре́мени го́да|времён го́да
  |вре́мени го́да|времена́м го́да
  |вре́мя го́да|времена́ го́да
  |вре́менем го́да|времена́ми го́да
  |о вре́мени го́да|о времена́х го́да}}""",
  u"""{{ru-decl-noun
  |трёхэта́жное сло́во|трёхэта́жные слова́
  |трёхэта́жного сло́ва|трёхэта́жных слов
  |трёхэта́жному сло́ву|трёхэта́жным слова́м
  |трёхэта́жное сло́во|трёхэта́жные слова́
  |трёхэта́жным сло́вом|трёхэта́жными слова́ми
  |трёхэта́жном сло́ве|трёхэта́жных слова́х}}""",
  u"""{{ru-decl-noun
  |шишкови́дная железа́|шишкови́дные же́лезы
  |шишкови́дной железы́|шишкови́дных желёз
  |шишкови́дной железе́|шишкови́дным железа́м
  |шишкови́дную железу́|шишкови́дные же́лезы
  |шишкови́дной железо́й|шишкови́дными железа́ми
  |о шишкови́дной железе́|о шишкови́дных железа́х}}""",
  u"""{{ru-decl-noun
  |кастрю́лька молока́|кастрю́льки молока́
  |кастрю́льки молока́|кастрю́лек молока́
  |кастрю́льке молока́|кастрю́лькам молока́
  |кастрю́льку молока́|кастрю́льки молока́
  |кастрю́лькой молока́|кастрю́льками молока́
  |о кастрю́льке молока́|о кастрю́льках молока́}}""",
  u"""{{ru-decl-noun
  |пау́к-во́лк|пауки́-во́лки
  |паука́-во́лка|пауко́в-волко́в
  |пауку́-во́лку|паука́м-волка́м
  |паука́-во́лка|пауко́в-волко́в
  |пауко́м-во́лком|паука́ми-волка́ми
  |о пауке́-во́лке|о паука́х-волка́х}}""",
  u"""{{ru-decl-noun
  |ка́рточная игра́|ка́рточные и́гры
  |ка́рточной игры́|ка́рточных игр
  |ка́рточной игре́|ка́рточным и́грам
  |ка́рточную игру́|ка́рточные и́гры
  |ка́рточной игро́й|ка́рточными и́грами
  |о ка́рточной игре́|о ка́рточных и́грах}}""",
  u"""{{ru-decl-noun
  |ско́рая по́мощь|ско́рые по́мощи
  |ско́рой по́мощи|ско́рых по́мощей
  |ско́рой по́мощи|ско́рым по́мощам
  |ско́рую по́мощь|ско́рые по́мощи
  |ско́рой по́мощью|ско́рыми по́мощами
  |о ско́рой по́мощи|о ско́рых по́мощах}}""",
  u"""{{ru-decl-noun
  |со́лнечный ве́тер|со́лнечные ве́тры
  |со́лнечного ве́тра|со́лнечных ветро́в
  |со́лнечному ве́тру|со́лнечным ветра́м
  |со́лнечный ве́тер|со́лнечные ве́тры
  |со́лнечным ве́тром|со́лнечными ветра́ми
  |со́лнечном ве́тре|со́лнечных ветра́х
  }}""",
  u"""{{ru-decl-noun
  |монго́льский язы́к|монго́льские языки́
  |монго́льского языка́|монго́льских языко́в
  |монго́льскому языку́|монго́льским языка́м
  |монго́льский язы́к|монго́льские языки́
  |монго́льским языко́м|монго́льскими языка́ми
  |о монго́льском языке́|о монго́льских языка́х}}""",
  u"""{{ru-decl-noun
  |головна́я боль|головны́е бо́ли|головно́й бо́ли|головны́х бо́лей|головно́й бо́ли|головны́м
   бо́лям|головну́ю боль|головны́е бо́ли|головно́й бо́лью|головны́ми бо́лями|о головно́й бо́ли|о головны́х бо́лях}}""",
  u"""{{ru-decl-noun-unc|Столи́чная
  |Столи́чной
  |Столи́чной
  |Столи́чную
  |[[Столи́чной]], [[Столи́чною]]
  |о Столи́чной}}""",
  u"""{{ru-decl-noun-unc
  |несоверше́нный вид
  |несоверше́нного ви́да
  |несоверше́нному ви́ду
  |несоверше́нный вид
  |несоверше́нным ви́дом
  |о несоверше́нном ви́де|}}""",
  u"""{{ru-decl-noun-unc
  |Бо́сния и Герцегови́на
  |Бо́снии и Герцегови́ны
  |Бо́снии и Герцегови́не
  |Бо́снию и Герцегови́ну
  |Бо́снией и Герцегови́ной
  |о Бо́снии и Герцегови́не}}""",
  u"""{{ru-decl-noun-unc
  |Росси́йская Сове́тская Федерати́вная Социалисти́ческая Респу́блика
  |Росси́йской Сове́тской Федерати́вной Социалисти́ческой Респу́блики
  |Росси́йской Сове́тской Федерати́вной Социалисти́ческой Респу́блике
  |Росси́йскую Сове́тскую Федерати́вную Социалисти́ческую Респу́блику
  |Росси́йской Сове́тской Федерати́вной Социалисти́ческой Респу́бликой
  |о Росси́йской Сове́тской Федерати́вной Социалисти́ческой Респу́блике|}}""",
  u"""{{ru-decl-noun-unc
  |Ма́лая Азия
  |Ма́лой Азии
  |Ма́лой Азии
  |Ма́лую Азию
  |Ма́лой Азией, Ма́лою Азиею
  |о Ма́лой Азии}}""",
  u"""{{ru-decl-noun-unc
  |Жёлтая река́
  |Жёлтой реки́
  |Жёлтой реке́
  |Жёлтую ре́ку
  |Жёлтой реко́й
  |о Жёлтой реке́}}""",
  u"""{{ru-decl-noun-unc|
  Дже́к-Потроши́тель|
  Дже́ка-Потроши́теля|
  Дже́ку-Потроши́телю|
  Дже́ка-Потроши́теля|
  Дже́ком-Потроши́телем|
  Дже́ке-Потроши́теле|}}""",
  u"""{{ru-decl-noun-unc
  |ни́жнее бельё
  |ни́жнего белья́
  |ни́жнему белью́
  |ни́жнее бельё
  |ни́жним бельём
  |ни́жнем белье́}}""",
  u"""{{ru-decl-noun-unc
  |Алта́йский край
  |Алта́йского кра́я
  |Алта́йскому кра́ю
  |Алта́йский край
  |Алта́йским кра́ем
  |об Алта́йском кра́е}}""",
  u"""{{ru-decl-noun-unc|мавзоле́й в Галикарна́се
  |мавзоле́я в Галикарна́се
  |мавзоле́ю в Галикарна́се
  |мавзоле́й в Галикарна́се
  |мавзоле́ем в Галикарна́се
  |о мавзоле́е в Галикарна́се}}""",
  u"""{{ru-decl-noun-unc
  |коро́вье бе́шенство
  |коро́вьего бе́шенства
  |коро́вьему бе́шенству
  |коро́вье бе́шенство
  |коро́вьим бе́шенством
  |о коро́вьем бе́шенстве}}""",
  u"""{{ru-decl-noun-unc
  |го́ре лу́ковое
  |го́ря лу́кового
  |го́рю лу́ковому
  |го́ре лу́ковое
  |го́рем лу́ковым
  |о го́ре лу́ковом}}""",
  u"""{{ru-decl-noun-unc
  |Шалта́й-Болта́й
  |Шалта́я-Болта́я
  |Шалта́ю-Болта́ю
  |Шалта́я-Болта́я
  |Шалта́ем-Болта́ем
  |о Шалта́е-Болта́е}}""",
  u"""{{ru-decl-noun-unc
  |разо́к
  |-
  |-
  |разо́к
  |-
  |-
  }}""",
  u"""{{ru-proper noun|[[британский|Брита́нские]] [[остров|острова́]]|m-in-p}}
  
  # [[British Isles]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |Брита́нские острова́
  |Брита́нских острово́в
  |Брита́нским острова́м
  |Брита́нские острова́
  |Брита́нскими острова́ми
  |о Брита́нских острова́х}}""",
  u"""{{ru-proper noun|[[остров|острова́]] Уо́ллис и Футу́на|m-in-p}}
  
  # [[Wallis and Futuna]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |острова́ Уо́ллис и Футу́на
  |острово́в Уо́ллис и Футу́на
  |острова́м Уо́ллис и Футу́на
  |острова́ Уо́ллис и Футу́на
  |острова́ми Уо́ллис и Футу́на
  |об острова́х Уо́ллис и Футу́на}}""",
  u"""{{ru-proper noun|[[Соломон|Соломо́новы]] [[остров|острова́]]|m-in-p}}
  
  # [[Solomon Islands]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |Соломо́новы острова́
  |Соломо́новых острово́в
  |Соломо́новым острова́м
  |Соломо́новы острова́
  |Соломо́новыми острова́ми
  |о Соломо́новых острова́х}}""",
  u"""{{ru-noun|[[карманный|карма́нные]] [[часы́]]|m-in-p}}
  
  # [[pocket watch]] {{gloss|watch}}
  
  ====Declension====
  {{ru-decl-noun-pl
  |карма́нные часы́
  |карма́нных часо́в
  |карма́нным часа́м
  |карма́нные часы́
  |карма́нными часа́ми
  |о карма́нных часа́х}}""",
  u"""{{ru-noun|[[сухопутный|сухопу́тные]] [[сила|си́лы]]|f-in-p}}
  
  # {{context|military|lang=ru}} [[land]] [[forces]], [[army]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |сухопу́тные си́лы
  |сухопу́тных сил
  |сухопу́тным си́лам
  |сухопу́тные си́лы
  |сухопу́тными си́лами
  |о сухопу́тных си́лах}}""",
  u"""{{ru-noun|[[танковый|та́нковые]] [[войско|войска́]]|n-p}}
  
  # {{context|military|lang=ru}} [[armored]] [[troops]], [[armoured]] [[troops]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |та́нковые войска́
  |та́нковых во́йск
  |та́нковым войска́м
  |та́нковые войска́
  |та́нковыми войска́ми
  |о та́нковых войска́х}}""",
  u"""{{ru-noun|[[брю́ки]]-[[галифе́]]|tr=brjúki-galifɛ́|f-in-p}}
  
  # {{context|military|lang=ru}} [[flared]] [[breeches]]
  
  ====Declension====
  {{ru-decl-noun-pl
  |брю́ки-галифе́
  |брюк-галифе́
  |брю́кам-галифе́
  |брю́ки-галифе́
  |брю́ками-галифе́
  |о брю́ках-галифе́}}""",
  u"""{{ru-proper noun|[[объединённый|Объединённые]] [[нация|На́ции]]|f-in-p}}
  
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
    text = blib.parse(pagetext)
    page = Page()
    newtext, comment = infer_one_page_decls(page, 1, text)
    msg("newtext = %s" % unicode(newtext))
    msg("comment = %s" % comment)

if mockup:
  test_infer()
else:
  for page, index in iter_pages(blib.references("Template:ru-decl-noun")):
    blib.do_edit(page, index, infer_one_page_decls, save=save)

