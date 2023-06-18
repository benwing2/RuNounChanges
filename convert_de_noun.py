#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

vowels = "aeiouyäöüAEIOUYÄÖÜ"
capletters = "A-ZÄÖÜ"
CAP = "[" + capletters + "]"
V = "[" + vowels + "]"
NV = "[^" + vowels + "]"

umlaut = {
  "a": "ä",
  "A": "Ä",
  "o": "ö",
  "O": "Ö",
  "u": "ü",
  "U": "Ü",
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


def analyze_form(pagetitle, form, default, do_stem=False):
  if form == default:
    return "+"
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


def analyze_forms(pagetitle, forms, default, do_stem=False, joiner=":", old_contractions=False):
  forms = [analyze_form(pagetitle, form, default, do_stem=do_stem) for form in forms]
  forms = [form or "-" for form in forms]
  if old_contractions:
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
  elif re.search("[sßxz]$", lemma):
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
  return ",".join(str(declt) for declt in declts)


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


def construct_default_equiv(lemma, gender):
  if gender == "m":
    lemma = re.sub("e$", "", lemma)
    return lemma + "in"
  if gender == "f":
    lemma = re.sub("in$", "", lemma)
    if lemma.endswith("es"):
      lemma += "e"
    return lemma
  return None


def do_headword_template(headt, declts, pagetitle, subsections, subsection_with_head, subsection_with_declts, pagemsg):
  notes = []

  def analyze_declts(declts, pagetitle, headword_gens, headword_pls):
    decl_genders_gens_and_pls = []
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
            pagemsg("WARNING: Saw %s=%s, can't handle yet: %s" % (param, getp(param), str(declt)))
            return None
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
            pagemsg("WARNING: Unrecognized arg1=%s: %s" % (arg1, str(declt)))
            return None
          decl_gens = convert_gens(pagetitle, [gen], from_decl=True)
        num = getp("n")
        if num == "sg":
          is_sg = True
        elif num not in ["full", ""]:
          pagemsg("WARNING: Unrecognized n=%s: %s" % (num, str(declt)))
          return None
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
          return None
        prev_is_weak = is_weak
        if prev_is_sg is not None and prev_is_sg != is_sg:
          pagemsg("WARNING: Saw declension template with sg=%s different from previous sg=%s: %s"
              % (is_sg, prev_is_sg, declts_to_unicode(declts)))
          return None
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
      return None
    if len(all_decl_gens) != len(first_decl_gens) and len(all_decl_pls) != len(first_decl_pls):
      pagemsg("WARNING: Multiple declension templates with different both genitives and plurals: %s"
          % declts_to_unicode(declts))
      return None

    is_weak = prev_is_weak
    is_sg = prev_is_sg
    declspec = ":".join(all_decl_genders)

    def compute_part(declspec, headword_parts, all_decl_parts, get_default_part, desc):
      defparts = []
      for gender in all_decl_genders:
        defpart = pagetitle + get_default_part(pagetitle, gender, is_weak)
        if defpart not in defparts:
          defparts.append(defpart)
      if all_decl_parts == defparts:
        declspec += ","
      else:
        all_decl_part_forms = analyze_forms(pagetitle, all_decl_parts, None)
        if set(headword_parts) == set(all_decl_parts):
          headword_part_forms = analyze_forms(pagetitle, headword_parts, None)
          if headword_part_forms != all_decl_part_forms:
            pagemsg("NOTE: Headword %s(s) %s same as all decl %s(s) %s but analyzed form(s) different (probably different ordering), preferring headword analyzed form(s) %s over decl analyzed form(s) %s: declts=%s"
                % (desc, ",".join(headword_parts), desc, ",".join(all_decl_parts), headword_part_forms, all_decl_part_forms,
                  declts_to_unicode(declts)))
            all_decl_part_forms = headword_part_forms
        else:
          pagemsg("WARNING: Headword %s(s) %s not same as all decl %s(s) %s, continuing"
              % (desc, ",".join(headword_parts), desc, ",".join(all_decl_parts)))
        declspec += ",%s" % all_decl_part_forms
      return declspec

    if "m" in all_decl_genders or "n" in all_decl_genders:
      declspec = compute_part(declspec, headword_gens, all_decl_gens, get_default_gen, "genitive")
    if "p" not in all_decl_genders:
      declspec = compute_part(declspec, headword_pls, all_decl_pls, get_default_pl, "plural")
    declspec = re.sub(",*$", "", declspec)
    if is_weak:
      declspec += ".weak"
    if is_sg:
      declspec += ".sg"
    if ss:
      declspec += ".ss"
    return declspec, all_decl_genders, all_decl_gens, all_decl_pls

  old_style_headt = False
  for param in ["old", "2", "3", "4", "g1", "g2", "g3", "gen1", "gen2", "gen3", "pl1", "pl2", "pl3"]:
    if getparam(headt, param):
      old_style_headt = True
      break
  if not old_style_headt:
    pagemsg("NOTE: Skipping new-style headt=%s%s" % (str(headt),
      declts and ", declts=%s" % declts_to_unicode(declts) or ""))
    return notes

  is_proper = tname(headt) == "de-proper noun"
  ss = False
  if declts:
    sses = [not not getparam(declt, "ss") for declt in declts]
    if len(set(sses)) > 1:
      pagemsg("WARNING: Saw inconsistent values for ss= in decl templates: %s" % declts_to_unicode(declts))
      return
    ss = list(set(sses)) == [True]
  if ss:
    if not pagetitle.endswith("ß"):
      pagemsg("WARNING: Bad ss=1 setting for pagetitle not ending in -ß: %s" % declts_to_unicode(declts))
      return
    # If ss specified, pretend pagetitle ends in -ss, as it does in post-1996 spelling. Later on we add .ss to the
    # headword and declension specs.
    pagetitle = re.sub("ß$", "ss", pagetitle)

  adjectival = any(tname(t).startswith("de-decl-adj+noun") for t in declts)
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
    pv = str(param.value)
    if pn not in ["1", "2", "3", "4", "m", "f", "old"] and not re.search("^(g|gen|pl|dim|m|f)[0-9]+$", pn) and (
        not adjectival or pn not in "head"):
      pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, pv, str(headt)))
      return
  if not genders:
    pagemsg("WARNING: No genders in head template: %s" % str(headt))
    return
  if "p" in genders and len(genders) > 1:
    pagemsg("WARNING: Saw gender 'p' and another gender: %s" % str(headt))
    return
  if "p" in genders and (gens or pls):
    pagemsg("WARNING: Saw genitive(s) or plural(s) with plural-only: %s" % str(headt))
    return
  saw_mn = "m" in genders or "n" in genders
  if not saw_mn and not adjectival:
    if gens and gens == [pagetitle]:
      gens = []
    if gens:
      pagemsg("WARNING: Saw genitive(s) with feminine-only gender: %s" % str(headt))
      return

  if adjectival:
    if len(declts) > 1:
      pagemsg("WARNING: Saw adjectival declension along with multiple declension templates, can't handle: %s"
        % declts_to_unicode(declts))
      return
    declt = declts[0]
    def getp(param):
      return getparam(declt, param)
    tn = tname(declt)
    m = re.search(r"^de-decl-adj\+noun(-sg)?-([mfn])$", tn)
    if m:
      default_equiv = None
      is_sg, gender = m.groups()
      adj = getp("1")
      noun = getp("2")
      if gender in ["m", "f"]:
        default_equiv = adj + ("e" if gender == "m" else "er")
        if noun:
          default_equiv += " " + construct_default_equiv(noun, gender)
      if gender in ["m", "n"]:
        noun_gen = getp("3")
        noun_pl = getp("4")
      else:
        noun_gen = "-"
        noun_pl = getp("3")
      noun_pl_full = getp("pl")
      adj_ending = "er" if gender == "m" else "e" if gender == "f" else "es"
      expected_lemma = adj + adj_ending
      if gender == "f":
        # Should be '-er' but we often see '-en' (weak form) instead
        expected_gens = [adj + "er", adj + "en"]
      else:
        expected_gens = [adj + "en"]
      if is_sg:
        expected_pls = []
      else:
        expected_pls = [adj + "e", adj + "en"]
      if not noun:
        if noun_gen != "-" or noun_pl_full or (noun_pl and noun_pl != "-"):
          pagemsg("WARNING: Bad parameters for adjectival noun: %s" % str(declt))
          return
        all_decl_genders = [gender]
      else:
        fake_declt = "{{de-decl-noun-%s%s|%s|pl=%s%s}}" % (gender, "" if gender == "f" else "|" + noun_gen, noun_pl, noun_pl_full, "|n=sg" if is_sg else "")
        fake_declt = list(blib.parse_text(fake_declt).filter_templates())[0]
        def analyze_headword_parts_for_noun(parts, desc):
          noun_headword_parts = []
          for part in parts:
            m = re.search("^([^ ]+) ([^ ]+)$", part.strip())
            if not m:
              pagemsg("WARNING: Can't analyze headword %s '%s' into adjective and noun, continuing: head=%s, decl=%s"
                  % (desc, part, str(headt), str(declt)))
              return []
            part_adj, part_noun = m.groups()
            noun_headword_parts.append(part_noun)
          return noun_headword_parts
        noun_headword_gens = analyze_headword_parts_for_noun(gens, "genitive")
        noun_headword_pls = analyze_headword_parts_for_noun(pls, "plural")

        retval = analyze_declts([fake_declt], noun, noun_headword_gens, noun_headword_pls)
        if retval is None:
          return
        declspec, all_decl_genders, all_decl_gens, all_decl_pls = retval
        expected_lemma = "%s %s" % (expected_lemma, noun)
        expected_gens = ["%s %s" % (expected_gen, gen) for expected_gen in expected_gens for gen in ([noun] if gender == "f" else all_decl_gens)]
        if is_sg:
          expected_pls = []
        else:
          expected_pls = ["%se %s" % (adj, pl) for pl in all_decl_pls]
      if pagetitle != expected_lemma:
        pagemsg("WARNING: For adjectival noun or adjective-noun combination, expected lemma '%s' but saw '%s': head=%s, decl=%s"
            % (expected_lemma, pagetitle, str(headt), str(declt)))
        return
      if set(genders) != set(all_decl_genders):
        pagemsg("WARNING: For adjectival noun or adjective-noun combination, expected gender(s) '%s' but saw '%s': head=%s, decl=%s"
            % (",".join(all_decl_genders), ",".join(genders), str(headt), str(declt)))
        return
      if not (set(gens) <= set(expected_gens)):
        pagemsg("WARNING: For adjectival noun or adjective-noun combination, expected genitive(s) '%s' but saw '%s': head=%s, decl=%s"
            % (",".join(expected_gens), ",".join(gens), str(headt), str(declt)))
        return
      if pls == ["-"]:
        if expected_pls:
          pagemsg("WARNING: For adjectival noun or adjective-noun combination, expected plural(s) '%s' but saw '%s': head=%s, decl=%s"
              % (",".join(expected_pls), ",".join(pls), str(headt), str(declt)))
          return
      elif not (set(pls) <= set(expected_pls)):
        pagemsg("WARNING: For adjectival noun or adjective-noun combination, expected plural(s) '%s' but saw '%s': head=%s, decl=%s"
            % (",".join(expected_pls), ",".join(pls), str(headt), str(declt)))
        return
      if not noun:
        declspec = "+"
        if is_sg:
          declspec += ".sg"
      else:
        if re.search("^" + CAP, adj):
          adj_lemma = adj.lower()
        else:
          adj_lemma = adj
        if adj_lemma in ["erst", "zweit", "dritt", "viert", "fünft", "sechst", "siebent", "acht", "neunt", "zehnt"]:
          adj_lemma += "e"
        adj_form = adj + adj_ending
        if adj_form.startswith(adj_lemma):
          adj_link = "[[%s]]%s" % (adj_lemma, adj_form[len(adj_lemma):])
        else:
          adj_link = "[[%s|%s]]" % (adj_lemma, adj_form)
        noun_link = "[[%s]]" % noun
        # This is less accurate than the above. Often head= is wrong.
        # Try to update adjective and noun links from head= if given.
        #head = getparam(headt, "head")
        #if head:
        #  m = re.search("^([^ ]*) ([^ ]*)$", head)
        #  if not m:
        #    pagemsg("WARNING: Can't parse head=%s for adjective-noun combination, continuing: head=%s, decl=%s"
        #        % (head, str(headt), str(declt)))
        #  else:
        #    head_adj_link, head_noun_link = m.groups()
        #    m = re.search(r"\[\[([^][]*)\|([^][]*)\]\]$", head_adj_link)
        #    if m:
        #      adj_link_lemma, adj_link_form = m.groups()
        #      if adj_link_form.startswith(adj_link_lemma):
        #        head_adj_link = "[[%s]]%s" % (adj_link_lemma, adj_link_form[len(adj_link_lemma):])
        #    if head_adj_link != adj_link:
        #      pagemsg("NOTE: Head-derived adjective link %s not same as decl-template-derived adjective link %s, using the former: head=%s, decl=%s"
        #          % (head_adj_link, adj_link, str(headt), str(declt)))
        #      adj_link = head_adj_link
        #    if head_noun_link != noun_link:
        #      pagemsg("NOTE: Head-derived noun link %s not same as decl-template-derived noun link %s, using the former: head=%s, decl=%s"
        #          % (head_noun_link, noun_link, str(headt), str(declt)))
        #      noun_link = head_noun_link
        declspec = "%s<+> %s<%s>" % (adj_link, noun_link, declspec)
      headspec = declspec
      is_both = is_proper and not is_sg
    else:
      pagemsg("WARNING: Unrecognized decl template(s): %s" % declts_to_unicode(declts))
      return

  else: # not adjectival
    if len(genders) == 1 and genders[0] in ["m", "f"]:
      default_equiv = construct_default_equiv(pagetitle, genders[0])
    headspec = ":".join(genders)
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
          headspec += ",%s" % analyze_forms(pagetitle, gens, None)
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
        headspec += ",%s" % analyze_forms(pagetitle, pls, None)
    headspec = re.sub(",*$", "", headspec)
    if is_weak:
      headspec += ".weak"
    if is_sg:
      headspec += ".sg"
    if ss:
      headspec += ".ss"

  extraspec = ""
  if dims:
    extraspec += "|dim=%s" % analyze_forms(pagetitle, dims, None, do_stem=True, joiner=",")
  if fems:
    extraspec += "|f=%s" % analyze_forms(pagetitle, fems, default_equiv, do_stem=True, joiner=",")
  if mascs:
    extraspec += "|m=%s" % analyze_forms(pagetitle, mascs, default_equiv, do_stem=True, joiner=",")

  if declts and not adjectival:
    retval = analyze_declts(declts, pagetitle, headword_gens, headword_pls)
    if retval is None:
      return
    declspec, all_decl_genders, all_decl_gens, all_decl_pls = retval
    if headspec != declspec:
      if set(all_decl_gens) <= set(headword_gens) and set(all_decl_pls) <= set(headword_pls):
        if set(all_decl_genders) == set(headword_genders):
          pagemsg("NOTE: Headword spec '%s' not same as declension spec '%s', but decl gens %s a subset of headword gens %s and decl pls %s a subset of headword pls %s and gender(s) %s agree: headt=%s, declt=%s"
              % (headspec, declspec, ",".join(all_decl_gens), ",".join(headword_gens), ",".join(all_decl_pls),
                ",".join(headword_pls), ",".join(all_decl_genders), str(headt), str(declt)))
          declspec = headspec
        else:
          pagemsg("WARNING: Headword spec '%s' not same as declension spec '%s', decl gens %s a subset of headword gens %s and decl pls %s a subset of headword pls %s, but decl gender(s) %s don't agree with headword gender(s) %s: headt=%s, declt=%s"
              % (headspec, declspec, ",".join(all_decl_gens), ",".join(headword_gens), ",".join(all_decl_pls),
                ",".join(headword_pls), ",".join(all_decl_genders), ",".join(headword_genders), str(headt), str(declt)))

          return
      else:
        pagemsg("WARNING: Headword spec '%s' not same as declension spec '%s' and either decl gens %s not a subset of headword gens %s or decl pls %s not a subset of headword pls %s, with decl gender(s) %s and headword gender(s) %s: headt=%s, declt=%s"
            % (headspec, declspec, ",".join(all_decl_gens), ",".join(headword_gens), ",".join(all_decl_pls),
              ",".join(headword_pls), ",".join(all_decl_genders), ",".join(headword_genders), str(headt), str(declt)))
        return

  if is_proper:
    headspec = headspec.replace(".sg", "")
    if is_both:
      if ".ss" in headspec:
        headspec = headspec.replace(".ss", ".both.ss")
      else:
        headspec += ".both"
  newheadt = "{{de-%s|%s%s}}" % ("proper noun" if is_proper else "noun", headspec, extraspec)
  headt_outmsg = "convert %s to new-format %s" % (str(headt), newheadt)
  outmsg = "Would " + headt_outmsg
  if declts:
    newdeclt = "{{de-ndecl|%s}}" % declspec
    declt_outmsg = "convert %s to %s" % (declts_to_unicode(declts), newdeclt)
    outmsg += " and " + declt_outmsg
  pagemsg(outmsg)

  if str(headt) != newheadt:
    newsectext, replaced = blib.replace_in_text(subsections[subsection_with_head], str(headt), newheadt, pagemsg, abort_if_warning=True)
    if not replaced:
      return
    notes.append(headt_outmsg)
    subsections[subsection_with_head] = newsectext
  if declts:
    declts_existing = "\n".join(str(declt) for declt in declts)
    newsectext, replaced = blib.replace_in_text(subsections[subsection_with_declts], declts_existing, newdeclt, pagemsg, abort_if_warning=True)
    if not replaced:
      return
    notes.append(declt_outmsg)
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
  for k in range(0, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])

    for t in parsed.filter_templates():
      tn = tname(t)
      origt = str(t)
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
            pagemsg("WARNING: Saw two head templates in same section: %s and %s" % (str(headt), str(t)))
            return
          pagemsg("NOTE: Saw head template without corresponding declension template, still processing: %s"
              % str(headt))
          this_notes = do_headword_template(headt, declts, pagetitle, subsections, subsection_with_head, subsection_with_declts, pagemsg)
          if this_notes is None:
            return
          notes.extend(this_notes)
        headt = t
        subsection_with_head = k
      elif tn.startswith("de-decl-adj+noun") or tn in decl_templates:
        if declts:
          if subsection_with_declts == k:
            pagemsg("NOTE: Saw declension template #%s without intervening head template: previous decl template(s)=%s, decl=%s%s"
                % (1 + len(declts), declts_to_unicode(declts), str(t),
                  headt and "; head=%s" % str(headt) or ""))
          else:
            pagemsg("WARNING: Saw declension template in new section without preceding head template: %s" % str(t))
            return
        if not headt:
          pagemsg("WARNING: Saw declension template without preceding head template: %s" % str(t))
          return
        declts.append(t)
        subsection_with_declts = k
  if headt:
    if not declts:
      pagemsg("NOTE: Saw head template without corresponding declension template, still processing: %s"
          % str(headt))
    this_notes = do_headword_template(headt, declts, pagetitle, subsections, subsection_with_head, subsection_with_declts, pagemsg)
    if this_notes is None:
      return
    notes.extend(this_notes)
  return "".join(subsections), notes


def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "German", pagemsg)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  if "=Etymology 1=" in secbody:
    notes = []
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    for k in range(2, len(etym_sections), 2):
      retval = process_text_in_section(index, pagetitle, etym_sections[k])
      if retval:
        newsectext, newnotes = retval
        etym_sections[k] = newsectext
        notes.extend(newnotes)
    secbody = "".join(etym_sections)
    sections[j] = secbody + sectail
    return "".join(sections), notes
  else:
    retval = process_text_in_section(index, pagetitle, secbody)
    if retval:
      secbody, notes = retval
      sections[j] = secbody + sectail
      return "".join(sections), notes


parser = blib.create_argparser("Convert {{de-noun}}/{{de-proper noun}} to new format",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
