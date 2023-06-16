#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

remove_stress = {
  u"á": "a",
  u"é": "e",
  u"í": "i",
  u"ó": "o",
  u"ú": "u",
}

add_stress = {
  "a": u"á",
  "e": u"é",
  "i": u"í",
  "o": u"ó",
  "u": u"ú",
}

vowel = u"aeiouáéíóúý"
V = "[" + vowel + "]"
C = "[^" + vowel + "]"

def get_def_forms(lemma, prep, pagemsg):
  if " " in lemma:
    # Try to preserve the brackets in the part after the verb, but don't do it
    # if there aren't the same number of left and right brackets in the verb
    # (which means the verb was linked as part of a larger expression).
    m = re.search("^(.*?)( .*)$", lemma)
    refl_clitic_verb, post = m.groups()
    left_brackets = re.sub(r"[^\[]", "", refl_clitic_verb)
    right_brackets = re.sub("[^\]]", "", refl_clitic_verb)
    if len(left_brackets) == len(right_brackets):
      refl_clitic_verb = blib.remove_links(refl_clitic_verb)
    else:
      lemma = blib.remove_links(lemma)
      m = re.search("^(.*?)( .*)$", lemma)
      if m:
        refl_clitic_verb, post = m.groups()
      else:
        refl_clitic_verb = lemma
        post = None
    end
  else:
    refl_clitic_verb = blib.remove_links(lemma)
    post = None
  m = re.search("^(.*?)(l[ao]s?)$", refl_clitic_verb)
  if m:
    refl_verb, clitic = m.groups()
  else:
    refl_verb = refl_clitic_verb
    clitic = None
  m = re.search("^(.*)(se)$", refl_verb)
  if m:
    verb, refl = m.groups()
  else:
    verb = refl_verb
    refl = None
  m = re.search(u"^(.*)([aeiáéí])r$", verb)
  if m:
    base, suffix_vowel = m.groups()
  else:
    pagemsg("WARNING: Unrecognized verb '%s'" % verb)
    return None
  suffix = remove_stress.get(suffix_vowel, suffix_vowel) + "r"
  ends_in_vowel = re.search("[aeo]$", base)
  if suffix == "ir" and ends_in_vowel:
    verb = base + u"ír"
  else:
    verb = base + suffix
  if prep:
    if blib.remove_links(" " + prep) != blib.remove_links(post):
      pagemsg("WARNING: Something wrong, prep=%s should match post=%s" % (prep, post))
      return None
    if len(" " + prep) > len(post):
      post = " " + prep
  if suffix == "ar":
    def_pres = base + "o"
  elif re.search(V + "c$", base):
    def_pres = base[:-1] + "zco" # parecer -> parezco, aducir -> aduzco; not ejercer -> ejerzo, uncir -> unzo
  elif base.endswith("c"):
    def_pres = base[:-1] + "zo" # ejercer -> ejerzo, uncir -> unzo, torcer -> tuerzo (with +ue)
  elif base.endswith("qu"):
    def_pres = base[:-2] + "co" # delinquir -> delinco
  elif base.endswith("g"):
    def_pres = base[:-1] + "jo" # coger -> cojo, afligir -> aflijo
  elif base.endswith("gu"):
    def_pres = base[:-2] + "go" # distinguir -> distingo
  elif base.endswith("u"):
    def_pres = base + "yo" # concluir -> concluyo
  elif base.endswith(u"ü"):
    def_pres = base[:-1] + "uyo" # argüir -> arguyo
  else:
    def_pres = base + "o"
  pres_stem = def_pres[:-1]
  def_pres_ie = None
  def_pres_ue = None
  def_pres_i = None
  def_pres_iacc = None
  def_pres_uacc = None
  m = re.search("^(.*)(" + V + ")(.*?)$", pres_stem)
  if m:
    before_last_vowel, last_vowel, after_last_vowel = m.groups()
    # allow i for adquirir -> adquiero, inquirir -> inquiero, etc.
    def_pres_ie = last_vowel in ["e", "i"] and before_last_vowel + "ie" + after_last_vowel + "o" or None
    # allow u for jugar -> juego; correctly handle avergonzar -> avergüenzo
    def_pres_ue = (
      last_vowel == "o" and before_last_vowel.endswith("g") and before_last_vowel + u"üe" + after_last_vowel + "o" or
      last_vowel in ["o", "u"] and before_last_vowel + "ue" + after_last_vowel + "o" or
      None
    )
    def_pres_i = last_vowel == "e" and before_last_vowel + "i" + after_last_vowel + "o" or None
    def_pres_iacc = (last_vowel == "e" or last_vowel == "i") and before_last_vowel + u"í" + after_last_vowel + "o" or None
    def_pres_uacc = last_vowel == "u" and before_last_vowel + u"ú" + after_last_vowel + "o" or None
  if suffix == "ar":
    if re.search("^" + C + "*[iu]$", base) or base == "gui": # criar, fiar, guiar, liar, etc.
      def_pret = base + "e"
    else:
      def_pret = base + u"é"
    def_pret = re.sub(u"gué$", u"güé", def_pret) # averiguar -> averigüé
    def_pret = re.sub(u"gé$", u"gué", def_pret) # cargar -> cargué
    def_pret = re.sub(u"cé$", u"qué", def_pret) # marcar -> marqué
    def_pret = re.sub(u"[çz]é$", u"cé", def_pret) # aderezar/adereçar -> aderecé
  elif suffix == "ir" and re.search("^" + C + "*u$", base): # fluir, fruir, huir, muir
    def_pret = base + "i"
  else:
    def_pret = base + u"í"
  end
  if suffix == "ar":
    def_part = base + "ado"
  elif ends_in_vowel:
    # reír -> reído, poseer -> poseído, caer -> caído, etc.
    def_part = base + u"ído"
  else:
    def_part = base + "ido"
  #if clitic or refl or post:
  #  def_pres = "[[" + def_pres + "]]"
  #  def_pres_ie = def_pres_ie and "[[" + def_pres_ie + "]]"
  #  def_pres_ue = def_pres_ue and "[[" + def_pres_ue + "]]"
  #  def_pres_i = def_pres_i and "[[" + def_pres_i + "]]"
  #  def_pres_iacc = def_pres_iacc and "[[" + def_pres_iacc + "]]"
  #  def_pres_uacc = def_pres_uacc and "[[" + def_pres_uacc + "]]"
  #  def_pret = "[[" + def_pret + "]]"
  #  def_part = "[[" + def_part + "]]"
  #if clitic:
  #  def_pres = clitic + " " + def_pres
  #  def_pres_ie = def_pres_ie and clitic + " " + def_pres_ie
  #  def_pres_ue = def_pres_ue and clitic + " " + def_pres_ue
  #  def_pres_i = def_pres_i and clitic + " " + def_pres_i
  #  def_pres_iacc = def_pres_iacc and clitic + " " + def_pres_iacc
  #  def_pres_uacc = def_pres_uacc and clitic + " " + def_pres_uacc
  #  def_pret = clitic + " " + def_pret
  #if refl:
  #  def_pres = "me " + def_pres
  #  def_pres_ie = def_pres_ie and "me " + def_pres_ie
  #  def_pres_ue = def_pres_ue and "me " + def_pres_ue
  #  def_pres_i = def_pres_i and "me " + def_pres_i
  #  def_pres_iacc = def_pres_iacc and "me " + def_pres_iacc
  #  def_pres_uacc = def_pres_uacc and "me " + def_pres_uacc
  #  def_pret = "me " + def_pret
  #if post:
  #  def_pres = def_pres + post
  #  def_pres_ie = def_pres_ie and def_pres_ie + post
  #  def_pres_ue = def_pres_ue and def_pres_ue + post
  #  def_pres_i = def_pres_i and def_pres_i + post
  #  def_pres_iacc = def_pres_iacc and def_pres_iacc + post
  #  def_pres_uacc = def_pres_uacc and def_pres_uacc + post
  #  def_pret = def_pret + post
  #  def_part = def_part + post

  ret = {}
  ret["verb"] = verb
  ret["accented_verb"] = base + add_stress.get(suffix_vowel, suffix_vowel) + "r"
  if refl and clitic:
    ret["linked_verb"] = (
      verb == ret["accented_verb"] and "[[" + verb + "]]" or
      "[[" + verb + "|" + ret.accented_verb + "]]"
    )
    ret["linked_verb"] = ret.linked_verb + "[[" + refl + "]][[" + clitic + "]]"
  else:
    ret["linked_verb"] = (
      "[[" + verb + "]]" + (refl and "[[" + refl + "]]" or "") + (clitic and "[[" + clitic + "]]" or "")
    )
  if refl and clitic:
    ret["full_verb"] = ret["accented_verb"] + refl + clitic
  else:
    ret["full_verb"] = verb + (refl or "") + (clitic or "")
  ret["clitic"] = clitic
  ret["refl"] = refl
  ret["post"] = post
  ret["pres"] = def_pres
  ret["pres_ie"] = def_pres_ie
  ret["pres_ue"] = def_pres_ue
  ret["pres_i"] = def_pres_i
  ret["pres_iacc"] = def_pres_iacc
  ret["pres_uacc"] = def_pres_uacc
  ret["pret"] = def_pret
  ret["part"] = def_part

  return ret

def make_verb_form_full(form, clitic, refl, post, is_part, do_link):
  if not form or form.startswith("+") or form == "-":
    return form
  if form == "no":
    return "-"
  if do_link and (clitic or post or refl and not is_part):
    form = "[[" + form + "]]"
  if clitic:
    form = clitic + " " + form
  if refl and not is_part:
    form = "me " + form
  if post:
    form = form + post
  return form


def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "es-verb" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn == "es-verb" and args.add_attn and not getp("1"):
      origt = str(t)
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        pagemsg("WARNING: No 1= but saw param %s=%s: %s" % (pn, pv, str(t)))
        break
      t.add("attn", "1")
      notes.append("add attn=1 to verb with missing 1=")
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
      else:
        pagemsg("No changes to %s" % str(t))
      continue

    if tn == "es-verb":
      origt = str(t)
      lemma = getparam(t, "head") or pagetitle
      if " " in lemma:
        pagemsg("WARNING: Space in lemma")
      prep = getp("prep")
      shouldlemma = getp("1") + getp("2") + ("se" if getp("ref") == "y" else "") + (" " + blib.remove_links(prep) if prep else "")
      if shouldlemma != blib.remove_links(lemma):
        pagemsg("WARNING: lemma=%s from 1/2/ref != lemma=%s from head or pagetitle: %s" % (
          shouldlemma, blib.remove_links(lemma), str(t)))
        continue
      d = get_def_forms(lemma, prep, pagemsg)
      if not d:
        continue
      if getp("part2") and not getp("part"):
        pagemsg("WARNING: Saw part2= without part=: %s" % str(t))
        part = [d["part"], getp("part2")]
      else:
        part = blib.fetch_param_chain(t, "part")
      pres = blib.fetch_param_chain(t, "pres")
      pret = blib.fetch_param_chain(t, "pret")
      part = ["+" if x == d["part"] else x for x in part]
      pret = ["+" if x == d["pret"] else x for x in pret]
      pres = [
        "+" if x == d["pres"] else
        "+ie" if x == d["pres_ie"] else
        "+ue" if x == d["pres_ue"] else
        "+i" if x == d["pres_i"] else
        u"+í" if x == d["pres_iacc"] else
        u"+ú" if x == d["pres_uacc"] else
        x for x in pres
      ]
      notes.append("convert {{es-verb}} to new format")
      if pres == ["+"]:
        notes.append("remove redundant present from {{es-verb}}")
        pres = []
      if pret == ["+"]:
        notes.append("remove redundant preterite from {{es-verb}}")
        pret = []
      if part == ["+"]:
        notes.append("remove redundant participle from {{es-verb}}")
        part = []
      for vowel_var in ["+ie", "+ue", "+i", u"+í", u"+ú"]:
        if vowel_var in pres:
          notes.append("replace vowel-varying present with '%s' in {{es-verb}}" % vowel_var)
      if "+" in part:
        notes.append("replace default participle with '+' in {{es-verb}}")

      head = getp("head")

      must_continue = False
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn == "1" and pv in ["m", "mf"]:
          pagemsg("WARNING: Extraneous param %s=%s in %s, ignoring" % (pn, pv, str(t)))
          continue
        if pn not in ["head", "1", "2", "ref", "pres", "pret", "part", "part2", "prep"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, pv, str(t)))
          must_continue = True
          break
      if must_continue:
        continue

      del t.params[:]
      def has_override(forms):
        return 1 if any(x and not x.startswith("+") for x in forms) else 0
      num_overrides = has_override(pres) + has_override(pret) + has_override(part)

      if d["post"] or (d["refl"] or d["clitic"]) and num_overrides >= 2:
        main_verb = d["full_verb"]
        if part:
          angle_brackets = "<%s,%s,%s>" % (":".join(pres), ":".join(pret), ":".join(part))
        elif pret:
          angle_brackets = "<%s,%s>" % (":".join(pres), ":".join(pret))
        elif pres:
          angle_brackets = "<%s>" % (":".join(pres))
        else:
          angle_brackets = "<>"
        if angle_brackets == "<>":
          if head:
            t.add("head", head)
        else:
          arg1 = "%s%s%s" % (main_verb, angle_brackets, d["post"] or "")
          t.add("1", arg1)
      else:
        if head:
          t.add("head", head)
        pres = [make_verb_form_full(x, d["clitic"], d["refl"], "", is_part=False, do_link=True) for x in pres]
        pret = [make_verb_form_full(x, d["clitic"], d["refl"], "", is_part=False, do_link=True) for x in pret]
        part = [make_verb_form_full(x, d["clitic"], d["refl"], "", is_part=True, do_link=True) for x in part]
        blib.set_param_chain(t, pres, "pres")
        blib.set_param_chain(t, pret, "pret")
        blib.set_param_chain(t, part, "part")

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
      else:
        pagemsg("No changes to %s" % str(t))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{es-verb}} templates to new format and remove redundant args",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--add-attn", action="store_true", help="Add attn=1 to verbs missing args")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Spanish verbs"])
