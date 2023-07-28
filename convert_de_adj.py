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
OMITTED_E = "\uFFF0"

umlaut = {
  "a": "ä",
  "A": "Ä",
  "o": "ö",
  "O": "Ö",
  "u": "ü",
  "U": "Ü",
}

def generate_default_stem(lemma, ss):
  if ss:
    return re.sub("ß$", "ss", lemma)
  if lemma.endswith("e"):
    return lemma[:-1]
  return re.sub("([ai])bel$", r"\1b" + OMITTED_E + "l", lemma)


def generate_default_comp(stem):
  return stem + "er"


def generate_default_sup(stem, ss):
  m = re.search("^(.*)" + OMITTED_E + "([lmnr])$", stem)
  if m:
    # If we omitted -e- in the stem, put it back. E.g. [[simpel]], stem ''simpl-'', comparative
    # ''simpler'', superlative ''simpelst-'', or [[abgeschlossen]], comparative ''abgeschlossener'' or
    # ''abgeschlossner'', superlative just ''abgeschlossenst-''.
    non_ending, ending = m.groups()
    if ss:
      # [[abgeschlossen]] -> ''abgeschloßner'' -> ''abgeschlossenst'' (pre-1996 spelling)
      non_ending = re.sub("ß$", "ss", non_ending)
    return non_ending + "e" + ending + "st"
  elif re.search("gr[oö](ß|ss)$", stem):
    # Write this way so we can be called either on positive or comparative stem.
    return stem + "t"
  elif re.search("h[oö]h$", stem):
    # [[hoch]], [[ranghoch]], etc.
    # Write this way so we can be called either on positive or comparative stem.
    return stem[:-2] + "öchst"
  elif re.search("n[aä]h$", stem):
    # [[nah]], [[äquatornah]], [[bahnhofsnah]], [[bodennah]], [[citynah]], [[hautnah]] (has no comp in dewikt),
    # [[körpernah]], [[zeitnah]], etc.
    # NOTE: [[erdnah]], [[praxisnah]] can be either regular (like [[froh]] below) or following [[nah]].
    # Write this way so we can be called either on positive or comparative stem.
    return stem[:-2] + "ächst"
  elif re.search("[aeiouäöü]h$", stem):
    # [[froh]], [[farbenfroh]], [[lebensfroh]], [[schadenfroh]], [[früh]], [[jäh]] (has only jähest in dewikt), [[rauh]],
    # [[roh]], [[weh]], [[zäh]]
    return [stem + "st", stem + "est"]
  elif re.search("e[rl]?nd$", stem):
    # Present participles; non-present-participles like [[elend]], [[behend]]/[[behende]], [[horrend]] need special-casing
    return stem + "st"
  elif re.search("[^wi]e[rl]?t$", stem):
    # Most adjectives in -et, -elt, -ert (past participles specifically), but not adjectives in -iert, -ielt or
    # non-past-participles in -wert; other non-past-participles like [[alert]], [[inert]], [[concret]], [[discret]],
    # [[obsolet]] need special-casing
    return stem + "st"
  elif re.search("[^e]igt$", stem):
    # Most adjectives in -igt (past participles specifically), but not adjectives in -eigt such as [[abgeneigt]];
    # exceptions like [[gewitzigt]], [[gerechtfertigt]] need special-casing
    return stem + "st"
  elif re.search("[ae][iuwy]$", stem):
    # Those ending in diphthongs can take either -est -or -st (scheu, neu, schlau, frei, blau/blaw, etc.)
    return [stem + "est", stem + "st"]
  elif re.search("[szxßdt]$", stem):
    if ss and stem.endswith("ß"):
      return stem[:-1] + "ssest"
    return stem + "est"
  elif stem.endswith("sk"):
    # [[burlesk]], [[chevaleresk]], [[dantesk]], [[grotesk]], [[pittoresk]], [[pythonesk]]; also [[brüsk]], [[promisk]]
    return stem + "est"
  elif re.search("[^i]sch$", stem):
    # Adjectives in -sch where it is not an adjective-forming ending typically can take either -est or -st; examples
    # are [[barsch]], [[falsch]], [[fesch]], [[forsch]]/[[nassforsch]], [[frisch]]/[[taufrisch]], [[harsch]],
    # [[keusch]]/[[unkeusch]], [[lasch]], [[morsch]], [[rasch]], [[wirsch]]/[[unwirsch]]; maybe [[krüsch]]/[[krütsch]]?
    # (dewikt says sup. only ''krüschst'', Duden says only ''krüschest''); a few can take only -est per dewikt:
    # [[deutsch]]/[[süddeutsch]]/[[teutsch]], [[hübsch]], [[krosch]], [[resch]], [[rösch]]
    # Cases where -sch without -isch occurs that is an adjective-forming ending need special-casing, e.g.
    # [[figelinsch]]
    return [stem + "est", stem + "st"]
  else:
    return stem + "st"


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


def analyze_stem(default_stem, stem, pagemsg):
  orig_default_stem = default_stem
  default_stem = default_stem.replace(OMITTED_E, "")
  if stem == default_stem:
    return "+", orig_default_stem
  if re.search("[ai]bel$", stem):
    pagemsg("WARNING: Probable mistaken stem %s in adjective ending in -abel/-ibel, correcting" % stem)
    return "+", orig_default_stem
  if re.search("e[lmnr]$", default_stem) and stem == default_stem[:-2] + default_stem[-1]:
    return "-e", default_stem[:-2] + OMITTED_E + default_stem[-1]
  pagemsg("WARNING: Can't analyze stem %s with respect to default stem %s, returning full stem" % (stem, default_stem))
  return stem, stem


def analyze_comp_sup(stems, forms, generate_default, desc, pagemsg):
  def do_generate_default(form):
    retval = generate_default(form)
    if type(retval) is not list:
      retval = [retval]
    return retval
  origforms = forms
  default_forms = [x for form in stems for x in do_generate_default(form)]
  umlauted_stems = [apply_umlaut(form) for form in stems]
  default_umlauted_forms = [x for form in umlauted_stems for x in (do_generate_default(form) if form else [None])]
  minus_e_stems = [re.sub("^(.*)e([lmnr])$", r"\1" + OMITTED_E + r"\2", stem) if re.search("e[lmnr]$", stem) else None for stem in stems]
  minus_e_forms_with_omitted_e = [x for form in minus_e_stems for x in (do_generate_default(form) if form else [None])]
  minus_e_forms_to_forms_with_omitted_e = {form.replace(OMITTED_E, ""): form for form in minus_e_forms_with_omitted_e if form}
  minus_e_forms = [form.replace(OMITTED_E, "") if form else None for form in minus_e_forms_with_omitted_e]
  retval_spec = []
  retval_forms = []

  def check_in_remainder(form, default_forms, to_append, map_to_source_forms=None):
    assert len(default_forms) > 0
    if not (set(default_forms) <= set(forms)):
      pagemsg("WARNING: Saw %s form %s a subset of generated forms '%s' = %s, but remaining generated forms are not in total forms %s"
        % (desc, form, to_append, ":".join(default_forms), ":".join(origforms)))
      return forms, False
    retval_spec.append(to_append)
    remaining_forms = []
    for form in forms:
      if form not in default_forms:
        remaining_forms.append(form)
      else:
        if map_to_source_forms:
          retval_forms.append(map_to_source_forms[form])
        else:
          retval_forms.append(form)
    return remaining_forms, True

  while forms:
    form = forms[0]
    if form in default_forms:
      forms, success = check_in_remainder(form, default_forms, "+")
      if success:
        continue
    if form in default_umlauted_forms:
      forms, success = check_in_remainder(form, default_umlauted_forms, "^")
      if success:
        continue
    if all(minus_e_forms) and form in minus_e_forms:
      # FIXME, handle '.ss'
      forms, success = check_in_remainder(form, minus_e_forms, "-e", minus_e_forms_to_forms_with_omitted_e)
      if success:
        continue
    if form.startswith(stems[0]):
      suffix = form[len(stems[0]):]
      forms_to_check = [stem + suffix for stem in stems]
      forms, success = check_in_remainder(form, forms_to_check, "+%s" % suffix)
      if success:
        continue
    if all(umlauted_stems) and form.startswith(umlauted_stems[0]):
      suffix = form[len(umlauted_stems[0]):]
      forms_to_check = [stem + suffix for stem in umlauted_stems]
      forms, success = check_in_remainder(form, forms_to_check, "^%s" % suffix)
      if success:
        continue
    pagemsg("WARNING: Can't analyze %s form %s with respect to stem(s) %s, returning full form"
      % (desc, form, ":".join(stems)))
    retval_spec.append(form)
    retval_forms.append(form)
    forms = forms[1:]
  return retval_spec, retval_forms


def process_spec(specs, stems, generate_default, ss, pagemsg):
  def do_generate_default(form):
    retval = generate_default(form)
    if type(retval) is not list:
      retval = [retval]
    return retval
  retval = []
  for spec in specs:
    if spec == "-":
      pass
    elif spec == "+":
      for stem in stems:
        retval.extend(do_generate_default(stem))
    elif spec.startswith("+"):
      ending = spec[1:]
      for stem in stems:
        retval.append(stem + ending)
    elif spec == "^":
      for stem in stems:
        retval.extend(do_generate_default(apply_umlaut(stem)))
    elif spec.startswith("^"):
      ending = spec[1:]
      for stem in stems:
        retval.append(apply_umlaut(stem) + ending)
    elif spec == "-e":
      for stem in stems:
        m = re.search("^(.*)[e" + OMITTED_E + "]([lmnr])$", stem)
        if not m:
          pagemsg("WARNING: Internal error: Can't match stem %s for -e" % stem)
          return None
        non_ending, ending = m.groups()
        if ss:
          non_ending = re.sub("ss$", "ß")
        retval.extend(do_generate_default(non_ending + OMITTED_E + ending))
    else:
      retval.append(spec)
  return retval


def generate_default_sup_from_comp(compspecs, analyzed_stems, ss, pagemsg):
  retval = []
  comps = process_spec(compspecs, analyzed_stems, generate_default_comp, ss, pagemsg)
  for comp in comps:
    if not comp.endswith("er"):
      pagemsg("WARNING: Comparative %s doesn't end in -er, can't form default superlative" % comp)
      return None
    else:
      default_sup = generate_default_sup(comp[:-2], ss)
      if type(default_sup) is not list:
        default_sup = [default_sup]
      for defsup in default_sup:
        if defsup not in retval:
          retval.append(defsup)
  return retval


def declts_to_unicode(declts):
  return ",".join(str(declt) for declt in declts)


def normalize_values(values, stem):
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
  newvals = [stem + val if val in ["er", "st", "est", "sten", "esten"] else val for val in newvals]
  return newvals


def do_headword_template(headt, declts, pagetitle, subsections, subsection_with_head, subsection_with_declts, pagemsg):
  notes = []

  def analyze_headt_or_declt(declt, headt, pagetitle):
    dtn = declt and tname(declt) or ""
    if "predonly" in dtn:
      return "predonly"
    if "-inc" in dtn:
      if "notcomp" not in dtn:
        pagemsg("WARNING: Saw declt=%s with '-inc' but without 'notcomp', can't handle" % str(declt))
        return None
      if "nopred" in dtn:
        return "indecl.pred:-"
      else:
        return "indecl"
      
    if headt and tname(headt) == "head":
      head_comps = []
      head_sups = []
    else:
      head_comps = headt and normalize_values(blib.fetch_param_chain(headt, "1", "comp"), pagetitle) or []
      head_sups = headt and normalize_values(blib.fetch_param_chain(headt, "2", "sup"), pagetitle) or []
      if head_comps == ["-"] and head_sups in [["-"], []]:
        head_comps = []
        head_sups = []
      head_sups = [re.sub("en$", "", sup) for sup in head_sups]
    decl_comps = []
    decl_sups = []
    ss = False
    if pagetitle.endswith("ß"):
      if declt and getparam(declt, "1").endswith("ss") or not declt and getparam(headt, "1").endswith("sser"):
        ss = True

    default_stem = generate_default_stem(pagetitle, ss)
    if declt:
      actual_stems = [getparam(declt, "1") or pagetitle]
    else:
      if pagetitle.endswith("e"):
        pagemsg("WARNING: No declt accompanying headt=%s and pagetitle ends in '-e', may be indeclinable, can't handle"
            % str(headt))
        return None
      pagemsg("NOTE: No stem in headt=%s, using pagetitle" % str(headt))
      actual_stems = [pagetitle]
    stemspecs, analyzed_stems = list(zip(*[analyze_stem(default_stem, stem, pagemsg) for stem in actual_stems]))
    if stemspecs == ("+",):
      stemspec = ""
    else:
      stemspec = "stem:" + ":".join(stemspecs)
    compspec = ""
    supspec = ""

    if declt and "notcomp" not in dtn:
      decl_comps = normalize_values(blib.fetch_param_chain(declt, "2", "comp"), actual_stems[0])
      decl_sups = normalize_values(blib.fetch_param_chain(declt, "3", "sup"), actual_stems[0])
      if decl_comps == ["-"] and decl_sups in [["-"], []]:
        # effectively notcomp
        decl_comps = []
        decl_sups = []
    if not head_comps and not head_sups and not decl_comps and not decl_sups:
      pagemsg("Non-comparable: headt=%s, declt=%s" % (str(headt), str(declt)))
    elif re.search("[ai]bel$", pagetitle):
      pagemsg("WARNING: Comparable adjective ending in -abel/-ibel, probable mistaken declension, correcting")
      compspec = "comp"
    else:
      if declt:
        if headt and tname(headt) != "head":
          if decl_comps != head_comps:
            pagemsg("WARNING: Headword comparative(s) %s not equal to decl comparative(s) %s, not changing: headt=%s, declt=%s" %
                (":".join(head_comps), ":".join(decl_comps), str(headt), str(declt)))
            return
          if decl_sups != head_sups:
            pagemsg("WARNING: Headword superlative(s) %s not equal to decl superlative(s) %s, not changing: headt=%s, declt=%s" %
                (":".join(head_sups), ":".join(decl_sups), str(headt), str(declt)))
            return
        comps = decl_comps
        sups = decl_sups
        if not comps and not sups:
          pagemsg("WARNING: Something wrong, saw declt=%s without comps/sups and headt=%s with comps/sups" % (
            str(declt), str(headt)))
          return
      else:
        comps = head_comps
        sups = head_sups

      compspecs, modified_comps = analyze_comp_sup(actual_stems, comps, generate_default_comp, "comparative", pagemsg)
      default_sup_from_comp = generate_default_sup_from_comp(compspecs, analyzed_stems, ss, pagemsg)
      if default_sup_from_comp is None:
        return
      if set(sups) == set(default_sup_from_comp):
        pagemsg("Superlative(s) %s same as default superlative(s) generated from comparative(s) %s" % (
          ":".join(sups), ":".join(comps)))
        supspecs = []
      else:
        pagemsg("Superlative(s) %s NOT same as default superlative(s) %s generated from comparative(s) %s" % (
          ":".join(sups), ":".join(default_sup_from_comp), ":".join(modified_comps)))
        supspecs, _ = analyze_comp_sup(analyzed_stems, sups, lambda stem: generate_default_sup(stem, ss), "superlative",
            pagemsg)
      if compspecs == ["+"]:
        compspec = "comp"
      else:
        compspec = "comp:%s" % ":".join(compspecs)
      if supspecs == []:
        supspec = ""
      else:
        supspec = "sup:%s" % ":".join(supspecs)
    predspec = ""
    if "nopred" in dtn or declt and (getparam(declt, "pred") == "-" or getparam(declt, "strong_pred")):
      predspec = "pred:-"
    ssspec = ""
    if ss:
      ssspec = "ss"
    newdecl_parts = [x for x in [stemspec, compspec, supspec, predspec, ssspec] if x]
    newdecl_spec = ".".join(newdecl_parts)
    return newdecl_spec

  if len(declts) > 1:
    pagemsg("WARNING: Multiple declts, can't handle: %s" % declts_to_unicode(declts))
    return None
  if declts:
    declt = declts[0]
  else:
    declt = None

  if headt and tname(headt) == "head":
    for param in headt.params:
      pn = pname(param)
      pv = str(param.value)
      if pn not in ["1", "2", "head"]:
        pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, pv, str(headt)))
        return

    for param in ["head"]:
      pv = getparam(headt, param)
      if pv:
        pagemsg("WARNING: Saw %s=%s in head template, can't handle: %s" % (param, pv, str(headt)))
        return

  elif headt:
    old_style_headt = False
    for param in ["old", "2", "comp1", "comp2", "comp3", "sup1", "sup2", "sup3"]:
      if getparam(headt, param):
        old_style_headt = True
        break
    if getparam(headt, "1") == "-":
      old_style_headt = True
    if not old_style_headt:
      if declts:
        pagemsg("WARNING: Something wrong, saw new-style headt=%s and old-style declts=%s" % (
          str(headt), declts_to_unicode(declts)))
        return
      else:
        pagemsg("NOTE: Skipping new-style headt=%s" % str(headt))
      return notes
    for param in headt.params:
      pn = pname(param)
      pv = str(param.value)
      if pn not in ["1", "2", "old", "head"] and not re.search("^(comp|sup)[0-9]+$", pn):
        pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, pv, str(headt)))
        return

    for param in ["head"]:
      pv = getparam(headt, param)
      if pv:
        pagemsg("WARNING: Saw %s=%s in head template, can't handle: %s" % (param, pv, str(headt)))
        return

  newdecl_spec = analyze_headt_or_declt(declt, headt, pagetitle)
  if newdecl_spec is None:
    return
  if newdecl_spec:
    newheadt = "{{de-adj|%s}}" % newdecl_spec
    newdeclt = "{{de-adecl|%s}}" % newdecl_spec
  else:
    newheadt = "{{de-adj}}"
    newdeclt = "{{de-adecl}}"

  if headt:
    headt_outmsg = "convert %s to new-format %s" % (str(headt), newheadt)
    outmsg = "Would " + headt_outmsg
  else:
    headt_outmsg = None
  if declt:
    declt_outmsg = "convert %s to %s" % (str(declt), newdeclt)
  else:
    declt_outmsg = None
  outmsg = "Would " + " and ".join(x for x in [headt_outmsg, declt_outmsg] if x)
  pagemsg(outmsg)

  if headt and str(headt) != newheadt:
    newsectext, replaced = blib.replace_in_text(subsections[subsection_with_head], str(headt), newheadt, pagemsg, abort_if_warning=True)
    if not replaced:
      return
    notes.append(headt_outmsg)
    subsections[subsection_with_head] = newsectext
  if declt:
    newsectext, replaced = blib.replace_in_text(subsections[subsection_with_declts], str(declt), newdeclt, pagemsg, abort_if_warning=True)
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
      if tn in ["de-adj", "de-adjective"] or tn == "head" and getp("1") == "de" and getp("2") == "adjective":
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
      elif tn == "de-decl-adj" or tn.startswith("de-decl-adj-"):
        if declts:
          if subsection_with_declts == k:
            pagemsg("NOTE: Saw declension template #%s without intervening head template: previous decl template(s)=%s, decl=%s%s"
                % (1 + len(declts), declts_to_unicode(declts), str(t),
                  headt and "; head=%s" % str(headt) or ""))
          else:
            pagemsg("NOTE: Saw declension template in new section without preceding head template: %s" % str(t))
        if not headt:
          pagemsg("NOTE: Saw declension template without preceding head template: %s" % str(t))
        declts.append(t)
        subsection_with_declts = k
  if headt and not declts:
    if tname(headt) == "head":
      pagemsg("NOTE: Saw raw head template %s without corresponding declension template, can't process"
        % str(headt))
      return
    pagemsg("NOTE: Saw head template without corresponding declension template, still processing: %s"
        % str(headt))
  if not headt and not declts:
    return
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


parser = blib.create_argparser("Convert {{de-adj}} and declensions to new format",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["German adjectives"])
