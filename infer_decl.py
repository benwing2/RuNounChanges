#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import pywikibot
import mwparserfromhell
import blib
from blib import msg, rmparam, getparam

save = False
mockup = False

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

def trymatch(forms, args, pagemsg):
  if mockup:
    return True
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
      if (case == "ins_sg" and "," in real_form and
          re.sub(",.*$", "", real_form) == pred_form):
        pagemsg("For case ins_sg, predicted form %s has an alternate form not in actual form %s; allowed" % (pred_form, real_form))
      else:
        pagemsg("For case %s, actual %s differs from predicted %s" % (case,
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
  return len(re.sub("[^" + vowels + "]", "", word)) == 1

# assumes word is unstressed
def make_ending_stressed(word):
  word = re.sub("([" + vowels_no_jo + "])([^" + vowels_no_jo + "]*)$",
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

def synthesize_singular(nompl, prepl, gender, pagemsg):
  soft = re.match(ur"^.*яхъ?$", prepl)
  m = re.match(ur"(.*)[аяыи]́?$", nompl)
  if not m:
    pagemsg("WARNING: Strange nom plural %s" % nompl)
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
      if case == "pre_sg" or case == "pre_pl":
        form = re.sub(u"^о(б|бо)? ", "", form) # eliminate leading preposition
      forms[case] = form
    i += 1

  lemma = forms["nom_pl"] if numonly == "pl" else forms["nom_sg"]
  if " " in lemma:
    words = separate_multiwords(forms)
    argses = []
    wordno = 0
    for wordforms in words:
      wordno += 1
      pagemsg("Inferring word #1: %s" % (wordforms["nom_pl"] if numonly == "pl" else wordforms["nom_sg"]))
      args = infer_word(wordforms, number, numonly, pagemsg)
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
      filterargs = [x for x in args if not re.match("[an]=", x)]
      if allargs:
        allargs.append("_")
      allargs.extend(filterargs)
    allargs += animacy + number
    pagemsg("Found a multi-word match: {{ru-noun-table|%s}}" % "|".join(allargs))
    return allargs
  else:
    args = infer_word(forms, number, numonly, pagemsg)
    return [x for x in args if x != "a=in"]

def infer_word(forms, number, numonly, pagemsg):
  # Check for invariable word
  caseforms = forms.values()
  allsame = True
  for caseform in caseforms[1:]:
    if caseform != caseforms[0]:
      allsame = False
      break
  if allsame:
    pagemsg("Found invariable word %s" % caseforms[0])
    return ["", caseforms[0], "*"]

  nompl = forms["nom_pl"]
  gensg = forms["gen_sg"]
  genpl = try_to_stress(forms["gen_pl"])
  prepl = forms["pre_pl"]
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

    # FIXME: Adjectives in -ий of the +ьий type
    if (re.match(u"^.*([ыиіо]й|[яаь]я|[oeь]e)$", make_unstressed(nomsg)) or
        numonly == "pl" and re.match(u"^.*[ыи]e$", make_unstressed(nompl))):
      args = ["", nomsg, "+"] + anim + number
      if trymatch(forms, args, pagemsg):
        pagemsg("Found a match: {{ru-noun-table|%s}}" % "|".join(args))
        return args

    stress = "any"
    plstress = "any"
    genders = [""]
    bare = [""]
    m = re.match(ur"(.*)([аяеоё])(́?)$", nomsg)
    if m:
      pagemsg("Nom sg %s refers to feminine 1st decl or neuter 2nd decl" % nomsg)
      stem = try_to_stress(m.group(1))
      ending = m.group(2)
      if m.group(3) or ending == u"ё":
        stress = "ending"
      else:
        stress = "stem"

      if numonly != "sg":
        # Try to find a stressed version of the stem
        if is_unstressed(stem):
          mm = re.match(ur"(.*)[аяыи]́?$", nompl)
          if not mm:
            pagemsg("WARNING: Don't recognize fem 1st-decl or neut 2nd-decl nom pl ending in form %s" % nompl)
          else:
            nomplstem = try_to_stress(mm.group(1))
            if make_unstressed(nomplstem) != stem:
              pagemsg("Nom pl stem %s not accent-equiv to nom sg stem %s" % (
                nomplstem, stem))
            elif nomplstem != stem:
              pagemsg("Replacing unstressed stem %s with stressed nom pl stem %s" %
                  (stem, nomplstem))
              stem = nomplstem

        if stem == genpl:
          pagemsg("Gen pl %s same as stem" % genpl)
        elif make_unstressed(stem) != make_unstressed(genpl):
          pagemsg("Stem %s not accent-equiv to gen pl %s" % (stem, genpl))
          bare = ["*", genpl]
        elif is_unstressed(stem):
          pagemsg("Replacing unstressed stem %s with accent-equiv gen pl %s" %
              (stem, genpl))
          stem = genpl
        else:
          pagemsg("Stem %s stressed one way, gen pl %s stressed differently" %
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
            pagemsg("WARNING: Don't recognize gen sg ending in form %s" % gensg)
            if ending == u"ь":
              genders = ["m", "f"]
          else:
            stem = try_to_stress(m.group(1))
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
              bare = ["*", [nomsg, stem + ending]]
            elif is_unstressed(stem):
              pagemsg("Replacing unstressed stem %s with accent-equiv nom sg stem %s" %
                  (stem, nomsgstem))
            else:
              pagemsg("Stem %s stressed one way, nom sg stem %s stressed differently" %
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
    if numonly == "pl":
      stress = "none"
    if stress == "any" or plstress == "any":
      pagemsg("WARNING: Using all stress patterns")
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
          if trymatch(forms, args, pagemsg):
            pagemsg("Found a match: {{ru-noun-table|%s}}" % "|".join(args))
            return args

    # I think these are always in -ов/-ев/-ин/-ын.
    #if re.match(nomsg, u"^.*([шщжчц]е|[ъоа]|)$"):
    if re.match(nomsg, u"^.*([ое]в|[ыи]н)([оаъ]?)$"):
      for adjpat in ["+short", "+mixed"]:
        args = ["", nomsg, adjpat] + anim + number
        if trymatch(forms, args, pagemsg):
          pagemsg("Found a match: {{ru-noun-table|%s}}" % "|".join(args))
          return args

  return None

def infer_one_page_decls(page, index, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, unicode(page.title()), txt))
  genders = set()
  for t in text.filter_templates():
    if unicode(t.name) == "ru-noun":
      m = re.match("^([mfn])", getparam(t, "2"))
      if not m:
        pagemsg("WARNING: Strange ru-noun template: %s" % unicode(t))
      else:
        genders.add(m.group(1))

  for t in text.filter_templates():
    if unicode(t.name).strip() in ["ru-decl-noun", "ru-decl-noun-unc", "ru-decl-noun-pl"]:
      if unicode(t.name) == "ru-decl-noun-pl":
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
  u"""{{ru-decl-noun|ма́льчик для битья́|ма́льчики для битья́|ма́льчика для битья́|ма́льчиков для битья́|ма́льчику для битья́|ма́льчикам для битья́|ма́льчика для битья́|ма́льчиков для битья́|ма́льчиком для битья́|ма́льчиками для битья́|о ма́льчике для битья́|о ма́льчиках для битья́}}"""]
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

