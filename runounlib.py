#!/usr/bin/python
# -*- coding: utf-8 -*-

import re

import rulib
import blib
from blib import getparam, rmparam

def arg1_is_stress(arg1):
  if not arg1:
    return None
  for arg in re.split(",", arg1):
    if not (re.search("^[a-f]'?'?$", arg) or re.search(r"^[1-6]\*?$", arg)):
      return None
  return True

def split_noun_decl_arg_sets(decl_template, pagemsg):
  # Split a noun declension from ru-noun+ or ru-proper noun+ into
  # a list of per-word objects, one per word in the declension (separated
  # by "_", "-" or "join:..."), where each per-word object is a list of
  # arg sets (separated by "or"), one per alternative declension of the word,
  # where each arg set is a list of arguments, e.g. ["b", u"поро́к", "*"].
  # We take care to handle cases where there is no lemma (it would default
  # to the page name).
  #
  # The list of arguments is normalized so that it always has at least two
  # elements, where the accent pattern is the first element and the lemma
  # itself is the second element. This is the case even if either the
  # accent pattern, lemma or both were omitted in the declension (in these
  # cases, an empty string is substituted for the omitted parameter).

  highest_numbered_param = 0
  for p in decl_template.params:
    pname = unicode(p.name)
    if re.search("^[0-9]+$", pname):
      highest_numbered_param = max(highest_numbered_param, int(pname))

  # Now gather the numbered arguments into arg sets, gather the arg sets into
  # groups of arg sets (one group per word), and gather the info for all
  # words. An arg set is a list of arguments describing a declension,
  # e.g. ["b", u"поро́к", "*"]. There may be multiple arg sets per word;
  # in particular, if a word has a compound declension consisting of two
  # or more declensions separated by "or". Code taken from ru-noun.lua,
  # modified to include at least two elements in each arg set.
  offset = 0
  arg_sets = []
  arg_set = []
  per_word_info = []
  for i in range(1, highest_numbered_param + 2):
    end_arg_set = False
    end_word = False
    val = getparam(decl_template, str(i))
    if i == highest_numbered_param + 1 or val in ["_", "-"] or re.search("^join:", val):
      end_arg_set = True
      end_word = True
    elif val == "or":
      end_arg_set = True

    if end_arg_set:
      if len(arg_set) == 0:
        arg_set.append("")
      if len(arg_set) == 1:
        arg_set.append("")
      arg_sets.append(arg_set)
      arg_set = []
      offset = i
      if end_word:
        per_word_info.append(arg_sets)
        arg_sets = []
    else:
      # If the first argument isn't stress, that means all arguments
      # have been shifted to the left one. We want to shift them
      # back to the right one, so we change the offset so that we
      # get the same effect of skipping a slot in the arg set.
      if i - offset == 1 and not arg1_is_stress(val):
        offset -= 1
        arg_set.append("")
      if i - offset > 4:
        pagemsg("WARNING: Too many arguments for argument set: arg %s = %s" %
            (i, (val or "(blank)")))
      arg_set.append(val)

  return per_word_info

def try_to_stress(form):
  if "//" in form:
    m = re.search("^(.*?)//(.*)$", form)
    # FIXME: This should stress the translit as well
    return rulib.try_to_stress(m.group(1)) + "//" + m.group(2)
  return rulib.try_to_stress(form)

def fixup_link(f):
  def fixup_one_link(m):
    lemma, infl = m.groups()
    # Make sure to remove accents, cf. [[десе́ртный|десе́ртное]]
    lemma = rulib.remove_accents(re.sub("#Russian$", "", lemma))
    if rulib.remove_accents(infl) == lemma:
      return "[[%s]]" % infl
    return "[[%s|%s]]" % (lemma, infl)

  return re.sub(r"\[\[([^\[\]|]*?)\|([^\[\]|]*?)\]\]", fixup_one_link, f)

def check_old_noun_headword_forms(headword_template, args, subpagetitle, pagemsg, laxer_comparison=False):
  # FORM1 is the forms from ru-noun (or ru-proper noun); FORM2 is the combined
  # set of forms from ru-noun-table, and needs to be split on commas.
  # FORM1_LEMMA is true if the FORM1 values come from the ru-noun lemma.
  def compare_forms(case, form1, form2, form1_lemma=False):
    # Split on individual words and allow monosyllabic accent differences.
    # FIXME: Will still have problems with [[X|Y]].
    def compare_single_form(f1, f2):
      words1 = re.split("[ -]", f1)
      words2 = re.split("[ -]", f2)
      if len(words1) != len(words2):
        return None
      for i in range(len(words1)):
        if words1[i] != words2[i]:
          w1 = fixup_link(words1[i])
          w2 = words2[i]
          # Allow case where existing is monosyllabic and missing a stress
          # compared with proposed
          w1 = {w1, try_to_stress(w1)}
          # Allow case where existing is missing a link as compared to
          # proposed (but not other way around; we don't want a link
          # disappearing)
          w2 = {w2, blib.remove_links(w2)}
          if not (w1 & w2):
            return None
      return True
    form1 = [fixup_link(re.sub(u"ё́", u"ё", x)) for x in form1]
    form2 = re.split(",", form2)
    if laxer_comparison or not form1_lemma:
      # Ignore manual translit in decl forms when comparing non-lemma forms;
      # not available from ru-noun (and not displayed anyway); also when
      # laxer_comparison is set, which happens in add_noun_decl
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

  headwords = blib.fetch_param_chain(headword_template, "1", "head", subpagetitle)
  translits = blib.fetch_param_chain(headword_template, "tr", "tr")
  for i in range(len(translits)):
    if len(headwords) <= i:
      pagemsg("WARNING: Not enough headwords for translit tr%s=%s, skipping" % (
        "" if i == 0 else str(i+1), translits[i]))
      return None
    else:
      headwords[i] += "//" + translits[i]
  genitives = blib.fetch_param_chain(headword_template, "3", "gen")
  plurals = blib.fetch_param_chain(headword_template, "4", "pl")
  genders = blib.fetch_param_chain(headword_template, "2", "g")
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
      pagemsg("WARNING: Raw case %s=%s contains footnote symbol" % (
        case, args[case + "_raw"]))

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
  for i, g in enumerate(genders):
    headword_template.add("g" if i == 0 else "g%s" % (i + 1), g)

  return params_to_preserve

def extract_headword_anim_spec(headword_template):
  genders = blib.fetch_param_chain(headword_template, "2", "g")
  saw_in = -1
  saw_an = -1
  for i,g in enumerate(genders):
    if re.search(r"\bin\b", g) and saw_in < 0:
      saw_in = i
    if re.search(r"\ban\b", g) and saw_an < 0:
      saw_an = i
  if saw_in >= 0 and saw_an >= 0 and saw_in < saw_an:
    return "ia"
  elif saw_in >= 0 and saw_an >= 0:
    return "ai"
  elif saw_an >= 0:
    return "an"
  elif saw_in >= 0:
    return "in"
  else:
    return None

# Convert given z-decl template to an ru-noun-table template given the
# subpagetitle (after any colon), pagemsg function, and optional headword
# template for converting bianimate animacy to either ai or ia.
def convert_zdecl_to_ru_noun_table(decl_z_template, subpagetitle, pagemsg,
    headword_template=None):
  zdecl = unicode(decl_z_template)
  zdeclcopy = blib.parse_text(zdecl).filter_templates()[0]
  decl_template = blib.parse_text("{{ru-noun-table}}").filter_templates()[0]
  # {{ru-decl-noun-z|звезда́|f-in|d|ё}}
  # {{ru-decl-noun-z|ёж|m-inan|b}}
  def getp(param):
    rmparam(zdeclcopy, param)
    return getparam(decl_z_template, param).strip()
  zlemma = getp("1")
  zgender_anim = getp("2")
  zstress = getp("3")
  zspecial = re.sub(u"ё", u";ё", getp("4"))
  m = re.search(r"^([mfn])-(an|in|inan)$", zgender_anim)
  if not m:
    pagemsg("WARNING: Unable to recognize z-decl gender/anim spec, skipping: %s" %
        zgender_anim)
    return None
  zgender, zanim = m.groups()

  if not zlemma:
    pagemsg("WARNING: Empty lemma, skipping: %s" % zdecl)
    return None

  # Remove unnecessary gender
  need_gender = (re.search(u"[иы]́?$", zlemma) or
      zgender == "n" and re.search(u"[яа]́?$", zlemma) or
      zgender == "m" and re.search(u"[яа]́?$", zlemma) and "(1)" in zspecial or
      zlemma.endswith(u"ь"))
  if not need_gender:
    normal_gender = (re.search(u"[оеё]́?$", zlemma) and "n" or
        re.search(u"[ая]́?$", zlemma) and "f" or "m")
    if normal_gender != zgender:
      pagemsg("WARNING: Gender mismatch, normal gender=%s, explicit gender=%s, keeping gender" %
          (normal_gender, zgender))
      need_gender = True
  if need_gender:
    pagemsg("Preserving gender in z-decl: %s" % zdecl)
    zspecial = zgender + zspecial
  else:
    pagemsg("Not preserving gender in z-decl: %s" % zdecl)

  # Remove unnecessary stress
  stressed_lemma = rulib.try_to_stress(zlemma)
  def check_defstress(defstr, reason):
    if defstr == zstress:
      pagemsg("Removing stress %s as default because %s: stressed_lemma=%s, template=%s" %
          (defstr, reason, stressed_lemma, zdecl))
    return defstr
  if rulib.is_nonsyllabic(stressed_lemma):
    default_stress = check_defstress("b", "nonsyllabic lemma")
  elif re.search(u"([аяоеыи]́|ё́?)$", stressed_lemma):
    default_stress = check_defstress("b", "ending-accented lemma")
  # No need for special-casing for ёнок or а́нин, as they are considered
  # accent a by ru-decl-noun-z
  else:
    default_stress = check_defstress("a", "stem-accented lemma")
  if default_stress == zstress:
    zstress = ""
  else:
    pagemsg("Not removing stress %s: %s" % (zstress, zdecl))

  # Remove unnecessary lemma
  if rulib.try_to_stress(subpagetitle) == stressed_lemma:
    pagemsg(u"Removing lemma %s because identical to subpagetitle %s (modulo monosyllabic stress differences): %s" %
        (zlemma, subpagetitle, zdecl))
    zlemma = ""

  if zstress:
    decl_template.add("1", zstress)
    offset = 1
  else:
    offset = 0
  decl_template.add(str(1 + offset), zlemma)
  decl_template.add(str(2 + offset), zspecial)
  if not getparam(decl_template, "3"):
    rmparam(decl_template, "3")
    if not getparam(decl_template, "2"):
      rmparam(decl_template, "2")
      if not getparam(decl_template, "1"):
        rmparam(decl_template, "1")

  headword_anim_spec = headword_template and extract_headword_anim_spec(headword_template)
  def anim_mismatch(zdecl_an, allowed_headword_ans):
    if headword_anim_spec and headword_anim_spec not in allowed_headword_ans:
      pagemsg("WARNING: z-decl anim %s disagrees with headword-derived %s (%s allowed): zdecl=%s, headword=%s" %
          (zdecl_an, headword_anim_spec, ",".join(allowed_headword_ans),
            zdecl, unicode(headword_template)))

  if zanim == "an":
    anim_mismatch(zanim, ["an"])
    pagemsg("Preserving z-decl -an as a=an: %s" % zdecl)
    decl_template.add("a", "an")
  elif zanim == "inan":
    anim_mismatch(zanim, ["ai", "ia"])
    if headword_anim_spec in ["ai", "ia"]:
      pagemsg("Converting z-decl -inan to a=%s: %s" %
          (headword_anim_spec, zdecl))
      decl_template.add("a", headword_anim_spec)
    else:
      pagemsg("WARNING: Unable to convert z-decl -inan to a=ai or a=ia, preserving as a=bi: zdecl=%s, headword=%s" %
          (zdecl, unicode(headword_template or "(no headword)")))
      decl_template.add("a", "bi")
  else:
    assert(zanim == "in")
    anim_mismatch(zanim, ["in"])
    pagemsg("Dropping z-decl -in as default: %s" % zdecl)

  znum = getp("n")
  if znum:
    if znum == "pl":
      pagemsg("WARNING: Found n=pl in z-decl, should convert manually to plural lemma: %s" %
          zdecl)
    pagemsg("Preserving z-decl n=%s: %s" % (znum, zdecl))
    decl_template.add("n", znum)

  preserve_params = [
    'nom_sg', 'gen_sg', 'dat_sg', 'acc_sg', 'ins_sg', 'prp_sg',
    'nom_pl', 'gen_pl', 'dat_pl', 'acc_pl', 'ins_pl', 'prp_pl',
    'voc'
  ]
  renamed_params = {'prp_sg':'pre_sg', 'prp_pl':'pre_pl'}

  for param in preserve_params:
    val = getp(param)
    if not val:
      continue
    newval = fixup_link(val)
    newvals = re.split(r"\s*,\s*", newval)
    newvals = [re.sub(r"^\[\[([^\[\]|]*)\]\]$", r"\1", x) for x in newvals]
    newval= ",".join(newvals)
    newparam = renamed_params.get(param, param)
    pagemsg("Preserving z-decl override %s=%s%s%s: %s" % (
      newparam, newval,
      "" if newparam == param else "; renamed from %s" % param,
      "" if newval == val else "; canonicalized from %s=%s" % (param, val),
      zdecl))
    decl_template.add(newparam, newval)
  loc = getp("loc")
  if loc:
    if loc == u"в":
      newloc = u"в +"
    elif loc == u"на":
      newloc = u"на +"
    else:
      newloc = u"в/на +"
    pagemsg("Preserving z-decl locative loc=%s (canonicalized from loc=%s): %s" %
        (newloc, loc, zdecl))
    decl_template.add("loc", newloc)
  par = getp("par")
  if par:
    newpar="+"
    pagemsg("Preserving z-decl partitive par=%s (canonicalized from par=%s): %s" %
        (newpar, par, zdecl))
    decl_template.add('par', newpar)
  notes = getp("note")
  if notes:
    pagemsg("WARNING: Found z-decl note=<%s>, converting to notes= but probably needs fixing up with footnote symbol and pltail or similar: %s" %
        (notes, zdecl))
    decl_template.add('notes', notes)

  if zdeclcopy.params:
    pagemsg("WARNING: Extraneous params in z-decl: %s" % unicode(zdeclcopy))

  #pagemsg("Replacing z-decl %s with regular decl %s" %
  #    (zdecl, unicode(decl_template)))
  return decl_template
