#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

vowels = u"aeiouyäöüAEIOUYÄÖÜ"
capletters = u"A-ZÄÖÜ"
CAP = "[" + capletters + "]"
V = "[" + vowels + "]"
NV = "[^" + vowels + "]"

umlaut = {
  "a": u"ä",
  "A": u"Ä",
  "o": u"ö",
  "O": u"Ö",
  "u": u"ü",
  "U": u"Ü",
}

decl_templates = {"de-decl-noun-m", "de-decl-noun-f", "de-decl-noun-n", "de-decl-noun-pl"}

def apply_umlaut(term):
  m = re.search("^(.*[^e])(e[lmnr]?)$", term)
  if m:
    stem, after = m.groups()
    # Nagel -> Nägel, Garten -> Gärten
    retval = apply_umlaut(stem)
    if not retval:
      return None
    return retval + after
  m = re.search("^(.*)([Aa])([Uu]" + NV + "*?)$", term)
  if not m:
    # Haar -> Härchen
    m = re.search("^(.*)([Aa])[Aa](" + NV + "*?)$", term)
  if not m:
    # Boot -> Bötchen
    m = re.search("^(.*)([Oo])[Oo](" + NV + "*?)$", term)
  if not m:
    # regular umlaut
    m = re.search("^(.*)([AaOouU])(" + NV + "*?)$", term)
  if m:
    before_v, v, after_v = m.groups()
    return before_v + umlaut[v] + after_v
  return None


def analyze_form(pagetitle, form, do_stem=False):
  if do_stem and pagetitle.endswith("e"):
    pagetitle = pagetitle[:-1]
  if form.startswith(pagetitle):
    retval = form[len(pagetitle):]
    if not re.search("^" + CAP, retval):
      return retval
  umlaut = apply_umlaut(pagetitle)
  if umlaut and form.startswith(umlaut):
    return "^" + form[len(umlaut):]
  if re.search("^" + CAP, form):
    return form
  return "!" + form


def analyze_forms(pagetitle, forms, do_stem=False, joiner=":"):
  forms = [analyze_form(pagetitle, form, do_stem=do_stem) for form in forms]
  forms = [form or "-" for form in forms]
  if set(forms) == {"es", "s"}:
    forms = ["(e)s"]
  elif set(forms) == {"s", "-"}:
    forms = ["(s)"]
  elif set(forms) == {"es", "-"}:
    forms = ["(es)"]
  return joiner.join(forms)


def get_n_ending(stem):
  if re.search("e$", stem) or re.search("e[lr]$", stem) and not re.search(NV + "[ei]e[lr]$", stem):
    # [[Kammer]], [[Feier]], [[Leier]], but not [[Spur]], [[Beer]], [[Manier]], [[Schmier]] or [[Vier]]
    # similarly, [[Achsel]], [[Gabel]], [[Tafel]], etc. but not [[Ziel]]
    return "n"
  elif re.search("[^aeAE]in$", stem):
    # [[Chinesin]], [[Doktorin]], etc.; but not words in -ein or -ain such as [[Pein]]
    return "nen"
  else:
    return "en"


def get_default_gen(lemma, gender, is_weak=False):
  if gender == "f":
    return ""
  elif is_weak:
    return get_n_ending(lemma)
  elif re.search("nis$", lemma):
    # neuter like [[Erlebnis]], [[Geheimnis]] or occasional masculine like [[Firnis]], [[Penis]]
    return "ses"
  elif re.search(NV + "us$", lemma):
    # [[Euphemismus]], [[Exitus]], [[Exodus]], etc.
    return ""
  elif re.search(u"[sßxz]$", lemma):
    return "es"
  else:
    return "s"


def get_default_pl(lemma, gender, is_weak=False):
  if re.search("nis$", lemma):
    # neuter like [[Erlebnis]], [[Geheimnis]] or feminine like [[Kenntnis]], [[Wildnis]],
    # or occasional masculine like [[Firnis]], [[Penis]]
    return "se"
  elif gender == "f" or is_weak or re.search("e$", lemma):
    return get_n_ending(lemma)
  elif gender == "n" and re.search("um$", lemma):
    # [[Museum]] -> [[Museen]], [[Vakuum]] -> [[Vakuen]]; not masculine [[Baum]] (plural [[Bäume]])
    # or [[Reichtum]] (plural [[Reichtümer]])
    return "!" + re.sub("um$", "en", lemma)
  elif re.search("mus$", lemma):
    # Algorithmus -> Algorithmen, Aphorismus -> Aphorismen
    return "!" + re.sub("us$", "en", lemma)
  elif re.search(NV + "us$", lemma):
    # [[Abakus]] -> [[Abakusse]], [[Zirkus]] -> [[Zirkusse]], [[Autobus]] -> [[Autobusse]];
    # not [[Applaus]] (plural [[Applause]])
    return "se"
  elif re.search("e[lmnr]$", lemma) and not re.search(NV + "[ei]e[lnmr]$", lemma):
    # check for weak ending -el, -em, -en, -er, e.g. [[Adler]], [[Meier]], [[Riedel]]; but exclude [[Heer]],
    # [[Bier]], [[Ziel]], which take -e by default
    return ""
  else:
    return "e"


def convert_gens(pagetitle, gens, from_decl=False):
  if len(gens) == 0:
    gens = [True]
  gens = [pagetitle + "s" if gen == True else gen for gen in gens]
  if len(gens) == 1:
    gen = gens[0]
    if gen == "(s)":
      return [pagetitle + "s", pagetitle]
    elif gen == "(es)":
      return [pagetitle + "es", pagetitle]
    elif gen == "(e)s":
      return [pagetitle + "es", pagetitle + "s"]
    elif gen in ["s", "es", "ses", "en", "n", "ns"]:
      return [pagetitle + gen]
    elif from_decl and gen in ["", "ens", "'"]:
      return [pagetitle + gen]
  return gens


def convert_pls(pagetitle, pls, is_proper=False):
  if len(pls) == 0:
    if is_proper:
      return ["-"]
    return [pagetitle + "en"]
  if len(pls) == 1:
    pl = pls[0]
    if pl in ["n", "en", "nen", "e", "se", "s"]:
      return [pagetitle + pl]
  return pls


def declts_to_unicode(declts):
  return ",".join(unicode(declt) for declt in declts)


def normalize_values(values):
  newvals = []
  for value in values:
    if value is True:
      newvals.append(value)
    else:
      # Split on comma or comma + <br> or " or "
      vals = re.split(r"(?:\s+or\s+|\s*,\s*(?:<br>)?\s*)", value.strip())
      # Remove raw links
      vals = [re.sub(r"^\[\[([^\[\]]*)\]\]$", r"\1", v) for v in vals]
      newvals.extend(vals)
  return newvals


def do_headword_template(headt, declts, pagetitle, subsections, subsection_with_head, subsection_with_declts, pagemsg):
  notes = []
  is_proper = tname(headt) == "de-proper noun"
  ss = False
  if declts:
    sses = [not not getparam(declt, "ss") for declt in declts]
    if len(set(sses)) > 1:
      pagemsg("WARNING: Saw inconsistent values for ss= in decl templates: %s" % declts_to_unicode(declts))
      return
    ss = list(set(sses)) == [True]
  if ss:
    if not pagetitle.endswith(u"ß"):
      pagemsg(u"WARNING: Bad ss=1 setting for pagetitle not ending in -ß: %s" % declts_to_unicode(declts))
      return
    # If ss specified, pretend pagetitle ends in -ss, as it does in post-1996 spelling. Later on we add .ss to the
    # headword and declension specs.
    pagetitle = re.sub(u"ß$", "ss", pagetitle)

  genders = blib.fetch_param_chain(headt, "1", "g")
  headword_genders = genders
  gens = normalize_values(blib.fetch_param_chain(headt, "2", "gen", True))
  pls = normalize_values(blib.fetch_param_chain(headt, "3", "pl"))
  dims = normalize_values(blib.fetch_param_chain(headt, "4", "dim"))
  fems = normalize_values(blib.fetch_param_chain(headt, "f"))
  mascs = normalize_values(blib.fetch_param_chain(headt, "m"))
  if gens == [True]:
    gens = []
  for param in headt.params:
    pn = pname(param)
    pv = unicode(param.value)
    if pn not in ["1", "2", "3", "4", "m", "f"] and not re.search("^(g|gen|pl|dim|m|f)[0-9]+$", pn):
      pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, pv, unicode(headt)))
      return
  if not genders:
    pagemsg("WARNING: No genders in head template: %s" % unicode(headt))
    return
  if "p" in genders and len(genders) > 1:
    pagemsg("WARNING: Saw gender 'p' and another gender: %s" % unicode(headt))
    return
  if "p" in genders and (gens or pls):
    pagemsg("WARNING: Saw genitive(s) or plural(s) with plural-only: %s" % unicode(headt))
    return
  saw_mn = "m" in genders or "n" in genders
  if not saw_mn:
    if gens and gens == [pagetitle]:
      gens = []
    if gens:
      pagemsg("WARNING: Saw genitive(s) with feminine-only gender: %s" % unicode(headt))
      return
  headspec = ":".join(genders)
  extraspec = ""
  is_sg = False
  is_both = False
  is_weak = False
  headword_gens = []
  headword_pls = []
  if headspec != "p":
    pls = convert_pls(pagetitle, pls, is_proper=is_proper)
    headword_pls = pls
    if saw_mn:
      gens = convert_gens(pagetitle, gens)
      headword_gens = gens
      if (len(gens) == 1 and any(gens[0] == pagetitle + ending for ending in ["n", "en", "ns", "ens"])
        and len(pls) == 1 and (pls[0] == "-" or any(pls[0] == pagetitle + ending for ending in ["n", "en"]))):
        is_weak = True
      def_gens = []
      for gender in genders:
        def_gen = pagetitle + get_default_gen(pagetitle, gender, is_weak)
        if def_gen not in def_gens:
          def_gens.append(def_gen)
      if set(def_gens) == set(gens):
        headspec += ","
      else:
        headspec += ",%s" % analyze_forms(pagetitle, gens)
    def_pls = []
    for gender in genders:
      def_pl = pagetitle + get_default_pl(pagetitle, gender, is_weak)
      if def_pl not in def_pls:
        def_pls.append(def_pl)
    if set(def_pls) == set(pls):
      headspec += ","
      if is_proper:
        is_both = True
    elif pls == ["-"]:
      is_sg = True
    else:
      headspec += ",%s" % analyze_forms(pagetitle, pls)
  headspec = re.sub(",*$", "", headspec)
  if is_weak:
    headspec += ".weak"
  if is_sg:
    headspec += ".sg"
  if ss:
    headspec += ".ss"
  if dims:
    extraspec += "|dim=%s" % analyze_forms(pagetitle, dims, do_stem=True, joiner=",")
  if fems:
    extraspec += "|f=%s" % analyze_forms(pagetitle, fems, do_stem=True, joiner=",")
  if mascs:
    extraspec += "|m=%s" % analyze_forms(pagetitle, mascs, do_stem=True, joiner=",")


  decl_genders_gens_and_pls = []
  if declts:
    prev_is_weak = None
    prev_is_sg = None
    for declt in declts:
      def getp(param):
        return getparam(declt, param)
      tn = tname(declt)
      gender = re.sub(".*-", "", tn)
      if gender == "pl":
        gender = "p"
      decl_gens = []
      decl_pls = []
      if gender != "p":
        is_weak = False
        is_sg = False
        for param in ["head", "ns", "gs", "ds", "as", "bs", "vs", "np", "gp", "dp", "ap", "notes"]:
          if getp(param):
            pagemsg("WARNING: Saw %s=%s, can't handle yet: %s" % (param, getp(param), unicode(declt)))
            return
        if gender in ["m", "n"]:
          arg1 = getp("1")
          if not arg1:
            gen = ""
          elif arg1 in ["n", "ns", "en", "ens"]:
            is_weak = True
            gen = arg1
          elif arg1 in ["s", "es", "ses", "(e)s", "(s)", "'"]:
            gen = arg1
          else:
            pagemsg("WARNING: Unrecognized arg1=%s: %s" % (arg1, unicode(declt)))
            return
          decl_gens = convert_gens(pagetitle, [gen], from_decl=True)
        num = getp("n")
        if num == "sg":
          is_sg = True
        elif num not in ["full", ""]:
          pagemsg("WARNING: Unrecognized n=%s: %s" % (num, unicode(declt)))
          return
        if not is_sg:
          if gender == "f":
            plsuffix = getp("1")
          else:
            plsuffix = getp("2")
          argpl = getp("pl")
          if argpl:
            pl = argpl
          else:
            pl = pagetitle + plsuffix
          if pl == "-":
            is_sg = True
          else:
            decl_pls = normalize_values([pl])
        if prev_is_weak is not None and prev_is_weak != is_weak:
          pagemsg("WARNING: Saw declension template with weak=%s different from previous weak=%s: %s"
              % (is_weak, prev_is_weak, declts_to_unicode(declts)))
          return
        prev_is_weak = is_weak
        if prev_is_sg is not None and prev_is_sg != is_sg:
          pagemsg("WARNING: Saw declension template with sg=%s different from previous sg=%s: %s"
              % (is_sg, prev_is_sg, declts_to_unicode(declts)))
          return
        prev_is_sg = is_sg
      decl_genders_gens_and_pls.append((gender, decl_gens, decl_pls))

    all_decl_genders = []
    all_decl_gens = []
    all_decl_pls = []
    for decl_gender, decl_gens, decl_pls in decl_genders_gens_and_pls:
      if decl_gender not in all_decl_genders:
        all_decl_genders.append(decl_gender)
      for decl_gen in decl_gens:
        if decl_gen not in all_decl_gens:
          all_decl_gens.append(decl_gen)
      for decl_pl in decl_pls:
        if decl_pl not in all_decl_pls:
          all_decl_pls.append(decl_pl)
    first_gender, first_decl_gens, first_decl_pls = decl_genders_gens_and_pls[0]
    if len(all_decl_genders) > 1 and (
      len(all_decl_gens) != len(first_decl_gens) or len(all_decl_pls) != len(first_decl_pls)
    ):
      pagemsg("WARNING: Multiple declension templates with different genders as well as different either genitives or plurals: %s"
          % declts_to_unicode(declts))
      return
    if len(all_decl_gens) != len(first_decl_gens) and len(all_decl_pls) != len(first_decl_pls):
      pagemsg("WARNING: Multiple declension templates with different both genitives and plurals: %s"
          % declts_to_unicode(declts))
      return

    is_weak = prev_is_weak
    is_sg = prev_is_sg
    declspec = ":".join(all_decl_genders)
    if "m" in all_decl_genders or "n" in all_decl_genders:
      defgens = []
      for gender in all_decl_genders:
        defgen = pagetitle + get_default_gen(pagetitle, gender, is_weak)
        if defgen not in defgens:
          defgens.append(defgen)
      if all_decl_gens == defgens:
        declspec += ","
      else:
        declspec += ",%s" % analyze_forms(pagetitle, all_decl_gens)
    if "p" not in all_decl_genders:
      defpls = []
      for gender in all_decl_genders:
        defpl = pagetitle + get_default_pl(pagetitle, gender, is_weak)
        if defpl not in defpls:
          defpls.append(defpl)
      if all_decl_pls == defpls:
        declspec += ","
      else:
        declspec += ",%s" % analyze_forms(pagetitle, all_decl_pls)
    declspec = re.sub(",*$", "", declspec)
    if is_weak:
      declspec += ".weak"
    if is_sg:
      declspec += ".sg"
    if ss:
      declspec += ".ss"

    if headspec != declspec:
      if set(all_decl_gens) <= set(headword_gens) and set(all_decl_pls) <= set(headword_pls):
        if set(all_decl_genders) == set(headword_genders):
          pagemsg("NOTE: Headword spec '%s' not same as declension spec '%s', but decl gens %s a subset of headword gens %s and decl pls %s a subset of headword pls %s and gender(s) %s agree: headt=%s, declt=%s"
              % (headspec, declspec, ",".join(all_decl_gens), ",".join(headword_gens), ",".join(all_decl_pls),
                ",".join(headword_pls), ",".join(all_decl_genders), unicode(headt), unicode(declt)))
          declspec = headspec
        else:
          pagemsg("WARNING: Headword spec '%s' not same as declension spec '%s', decl gens %s a subset of headword gens %s and decl pls %s a subset of headword pls %s, but decl gender(s) %s don't agree with headword gender(s) %s: headt=%s, declt=%s"
              % (headspec, declspec, ",".join(all_decl_gens), ",".join(headword_gens), ",".join(all_decl_pls),
                ",".join(headword_pls), ",".join(all_decl_genders), ",".join(headword_genders), unicode(headt), unicode(declt)))

          return
      else:
        pagemsg("WARNING: Headword spec '%s' not same as declension spec '%s' and either decl gens %s not a subset of headword gens %s or decl pls %s not a subset of headword pls %s, with decl gender(s) %s and headword gender(s) %s: headt=%s, declt=%s"
            % (headspec, declspec, ",".join(all_decl_gens), ",".join(headword_gens), ",".join(all_decl_pls),
              ",".join(headword_pls), ",".join(all_decl_genders), ",".join(headword_genders), unicode(headt), unicode(declt)))
        return

  if is_proper:
    headspec = headspec.replace(".sg", "")
    if is_both:
      if ".ss" in headspec:
        headspec = headspec.replace(".ss", ".both.ss")
      else:
        headspec += ".both"
  newheadt = "{{de-%s|%s%s}}" % ("proper noun" if is_proper else "noun", headspec, extraspec)
  outmsg = "Would convert %s to %s" % (unicode(headt), newheadt)
  if declts:
    newdeclt = "{{de-ndecl|%s}}" % declspec
    outmsg += " and %s to %s" % (declts_to_unicode(declts), newdeclt)
  pagemsg(outmsg)

  if unicode(headt) != newheadt:
    newsectext, replaced = blib.replace_in_text(subsections[subsection_with_head], unicode(headt), newheadt, pagemsg, abort_if_warning=True)
    if not replaced:
      return
    notes.append("replace old {{de-noun}} with new format")
    subsections[subsection_with_head] = newsectext
  if declts:
    declts_existing = "\n".join(unicode(declt) for declt in declts)
    newsectext, replaced = blib.replace_in_text(subsections[subsection_with_declts], declts_existing, newdeclt, pagemsg, abort_if_warning=True)
    if not replaced:
      return
    notes.append("replace old {{de-decl-noun*}} with new {{de-ndecl}}")
    subsections[subsection_with_declts] = newsectext

  return notes


def process_text_in_section(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  headt = None
  subsection_with_head = None
  declts = []
  subsection_with_declts = None
  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
  for k in xrange(0, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])

    for t in parsed.filter_templates():
      tn = tname(t)
      origt = unicode(t)
      def getp(param):
        return getparam(t, param)
      if tn in ["de-noun", "de-proper noun"]:
        if declts:
          this_notes = do_headword_template(headt, declts, pagetitle, subsections, subsection_with_head, subsection_with_declts, pagemsg)
          if this_notes is None:
            return
          notes.extend(this_notes)
          headt = None
          declts = []
        if headt:
          if subsection_with_head == k:
            pagemsg("WARNING: Saw two head templates in same section: %s and %s" % (unicode(headt), unicode(t)))
            return
          pagemsg("NOTE: Saw head template without corresponding declension template, still processing: %s"
              % unicode(headt))
          this_notes = do_headword_template(headt, declts, pagetitle, subsections, subsection_with_head, subsection_with_declts, pagemsg)
          if this_notes is None:
            return
          notes.extend(this_notes)
        headt = t
        subsection_with_head = k
      elif tn.startswith("de-decl-adj+noun"):
        pagemsg("WARNING: Saw adjectival noun template: %s" % unicode(t))
        return
      elif tn in decl_templates:
        if declts:
          if subsection_with_declts == k:
            pagemsg("NOTE: Saw declension template #%s without intervening head template: previous decl template(s)=%s, decl=%s%s"
                % (1 + len(declts), declts_to_unicode(declts), unicode(t),
                  headt and "; head=%s" % unicode(headt) or ""))
          else:
            pagemsg("WARNING: Saw declension template in new section without preceding head template: %s" % unicode(t))
            return
        if not headt:
          pagemsg("WARNING: Saw declension template without preceding head template: %s" % unicode(t))
          return
        declts.append(t)
        subsection_with_declts = k
  if headt:
    if not declts:
      pagemsg("NOTE: Saw head template without corresponding declension template, still processing: %s"
          % unicode(headt))
    this_notes = do_headword_template(headt, declts, pagetitle, subsections, subsection_with_head, subsection_with_declts, pagemsg)
    if this_notes is None:
      return
    notes.extend(this_notes)
  return "".join(subsections), notes


def process_text_on_page(index, pagetitle, text):
  if "=Etymology 1=" in text:
    notes = []
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", text, 0, re.M)
    for k in xrange(2, len(etym_sections), 2):
      retval = process_text_in_section(index, pagetitle, etym_sections[k])
      if retval:
        newsectext, newnotes = retval
        etym_sections[k] = newsectext
        notes.extend(newnotes)
    text = "".join(etym_sections)
    return text, notes
  else:
    return process_text_in_section(index, pagetitle, text)


parser = blib.create_argparser("Convert {{de-noun}}/{{de-proper noun}} to new format",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
