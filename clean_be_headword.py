#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import belib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")
  if pagetitle.startswith("Template:"):
    pagemsg("Skipping")
    return

  def process_noun_headt(t, declt=None):
    origt = str(t)
    origdeclt = declt and str(declt) or "None"
    def getp(param):
      return getparam(t, param)
    if tname(t) == "head":
      pos = getp("2")
      head = getp("head")
      headtr = getp("tr")
      g = getp("g")
      g2 = getp("g2")
      g3 = getp("g3")
      anim = ""
      decl = ""
      gen = ""
      gentr = ""
      pl = ""
      pltr = ""
      f = ""
      ftr = ""
      m = ""
      mtr = ""
      collective = ""
      collectivetr = ""
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "head", "tr", "g", "g2", "g3",
            # extra params to ignore
            "sc"]:
          pagemsg("WARNING: Unrecognized param %s=%s, skipping: %s" %
              (pn, str(param.value), origt))
          must_continue = True
          break
      if must_continue:
        return False
    else:
      pos = getp("pos")
      head = getp("1") or getp("head") or getp("sg")
      headtr = getp("tr")
      g = getp("2") or getp("g")
      g2 = getp("g2")
      g3 = getp("g3")
      anim = getp("a")
      decl = getp("decl")
      gen = getp("gen") or getp("3")
      gentr = getp("gentr")
      pl = getp("pl") or getp("4")
      pltr = getp("pltr")
      f = getp("f")
      ftr = getp("ftr")
      m = getp("m")
      mtr = getp("mtr")
      collective = getp("collective")
      collectivetr = getp("collectivetr")
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["pos", "1", "head", "sg", "tr", "2", "g", "g2", "g3",
            "a", "decl", "gen", "gentr", "3", "pl", "pltr", "4",
            "f", "ftr", "m", "mtr", "collective", "collectivetr",
            # extra params to ignore
            "sc"]:
          pagemsg("WARNING: Unrecognized param %s=%s, skipping: %s" %
              (pn, str(param.value), origt))
          must_continue = True
          break
      if must_continue:
        return False

    def clean_gender(g):
      gparts = g.split("-")
      realg = "?"
      realan = "?"
      realpl = ""
      for part in gparts:
        if part in ["m", "f", "n"]:
          realg = part
        elif part in ["an", "in"]:
          realan = part
        elif part == "p":
          realpl = part
        elif part != "?":
          pagemsg("WARNING: Encountered unrecognized gender part '%s' in gender '%s': %s" % (
            part, g, origt))
      an = anim
      if an in ["a", "an"]:
        an = "an"
      elif an in ["i", "in"]:
        an = "in"
      elif an:
        pagemsg("WARNING: Unrecognized animacy a=%s: %s" % (an, origt))
        an = "?"
      if realan != "?" and an and an != "?" and an != realan:
        pagemsg("WARNING: Animacy mismatch, anim %s in gender spec %s but a=%s: %s" % (
          realan, g, anim, origt))
      if realan == "?" and an:
        realan = an
      pl = ""
      if realpl:
        pl = "-%s" % realpl
      if realg == "?":
        pagemsg("WARNING: Unknown gender in gender spec %s: %s" % (g, origt))
      if realan == "?":
        pagemsg("WARNING: Unknown animacy in gender spec %s and a=%s: %s" % (g, anim, origt))
      if realg == "?" and realan == "?":
        return "?%s" % pl
      else:
        return "%s-%s%s" % (realg, realan, pl)

    if not g and not g2 and not g3:
      pagemsg("WARNING: No gender specified: %s" % origt)
      g = "?"
    genders = []
    if g:
      genders.append(clean_gender(g))
    if g2:
      genders.append(clean_gender(g2))
    if g3:
      genders.append(clean_gender(g3))

    if not head:
      head = pagetitle
    if decl and decl not in ["off", "no", "indeclinable"]:
      pagemsg("WARNING: Unrecognized value for decl=%s: %s" % (decl, origt))
      decl = ""
    if decl:
      if gen and gen != "-":
        pagemsg("WARNING: Indeclinable but gen=%s specified: %s" % (gen, origt))
      else:
        gen = "-"

    del t.params[:]
    if tname(t) == "head":
      blib.set_template_name(t, "be-" + pos)
    elif pos:
      t.add("pos", pos)

    def split_form(form):
      forms = re.split(r",\s*", form.strip())
      forms = [re.sub(r"^\[\[([^\[\]]*)\]\]$", r"\1", f) for f in forms]
      forms = [belib.add_accent_to_o(f) for f in forms]
      for f in forms:
        if "[[" in f:
          pagemsg("WARNING: Link in form %s: headword=%s, decl=%s" %
              (f, origt, origdeclt))
        if belib.needs_accents(f):
          pagemsg("WARNING: Form %s missing accents: headword=%s, decl=%s" %
              (f, origt, origdeclt))
      forms = [f for f in forms if f != "-"]
      return forms

    def handle_multiform(firstparam, restparam, form, formtr, declparam=None):
      if form:
        form = split_form(form)
      if declparam:
        if declparam == "-":
          declforms = ["-"]
        else:
          declforms = split_form(getparam(declt, declparam))
        if not form:
          form = declforms
        elif set(form) != set(declforms):
          pagemsg("WARNING: For %s=, headword form(s) %s disagree with decl form(s) %s: headword=%s, decl=%s" %
              (restparam, ",".join(form), ",".join(declforms), origt, origdeclt))
      if form:
        blib.set_param_chain(t, form, firstparam, restparam)
      if formtr:
        trparam = ("" if restparam == "head" else restparam) + "tr"
        if not form:
          pagemsg("WARNING: Saw %s=%s but no %s=: %s" %
              ("trparam", formtr, restparam, origt))
        elif len(form) > 1:
          pagemsg("WARNING: Saw %s=%s and multiple %ss %s: %s" %
              (trparam, formtr, restparam, ",".join(form), origt))
        t.add(trparam, formtr)

    decl_headparam = None
    decl_genparam = None
    decl_plparam = None
    if declt:
      decl_headparam = "1"
      tn = tname(declt)
      if tn == "be-decl-noun":
        decl_genparam = "3"
        decl_plparam = "2"
      elif tn == "be-decl-noun-unc":
        decl_genparam = "2"
        decl_plparam = "-"
      else:
        decl_genparam = "2"
      if tn == "be-decl-noun-pl":
        for g in genders:
          if not g.endswith("-p"):
            pagemsg("WARNING: Mismatch between headword gender %s and decl template %s: %s" % (
              g, str(declt), origt))
      else:
        for g in genders:
          if g.endswith("-p"):
            pagemsg("WARNING: Mismatch between headword gender %s and decl template %s: %s" % (
              g, str(declt), origt))

    handle_multiform("1", "head", head, headtr, decl_headparam)
    blib.set_param_chain(t, genders, "2", "g")
    handle_multiform("3", "gen", gen, gentr, decl_genparam)
    if not getp("3") and pl:
      t.add("3", "")
    handle_multiform("4", "pl", pl, pltr, decl_plparam)
    handle_multiform("m", "m", m, mtr)
    handle_multiform("f", "f", f, ftr)
    handle_multiform("collective", "collective", collective, collectivetr)

    if origt != str(t):
      notes.append("fix up {{%s}} to use new param convention" % tname(t))
      pagemsg("Replaced %s with %s" % (origt, str(t)))
    return True

  def process_verb_headt(t):
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    tr = getp("tr")
    if getp("2"):
      head = getp("1")
      g = getp("2")
    else:
      head = getp("head")
      g = getp("1") or getp("a")
    pf = blib.fetch_param_chain(t, "pf", "pf")
    impf = blib.fetch_param_chain(t, "impf", "impf")
    must_continue = False
    for param in t.params:
      pn = pname(param)
      if pn not in ["head", "tr", "1", "a", "2", "pf", "pf2", "pf3",
          "impf", "impf2", "impf3"]:
        pagemsg("WARNING: Unrecognized param %s=%s, skipping: %s" %
            (pn, str(param.value), origt))
        must_continue = True
        break
    if must_continue:
      return False
    del t.params[:]
    if not head:
      head = pagetitle
    if belib.needs_accents(head):
      pagemsg("WARNING: Head %s missing accents: %s" % (head, origt))
    if not g:
      pagemsg("WARNING: No aspect in verb headword: %s" % origt)
      g = "?"
    t.add("1", head)
    if tr:
      t.add("tr", tr)
    t.add("2", g)
    blib.set_param_chain(t, pf, "pf", "pf")
    blib.set_param_chain(t, impf, "impf", "impf")

    if origt != str(t):
      notes.append("fix up {{be-verb}} to use new param convention")
      pagemsg("Replaced %s with %s" % (origt, str(t)))
    return True


  def process_adj_headt(t):
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    tr = getp("tr")
    head = getp("head")
    if getp("1"):
      pagemsg("WARNING: Has 1=%s: %s" % (getp("1"), origt))
      return
    must_continue = False
    for param in t.params:
      pn = pname(param)
      if pn not in ["head", "tr"]:
        pagemsg("WARNING: Unrecognized param %s=%s, skipping: %s" %
            (pn, str(param.value), origt))
        must_continue = True
        break
    if must_continue:
      return False
    del t.params[:]
    if not head:
      head = pagetitle
    if belib.needs_accents(head):
      pagemsg("WARNING: Head %s missing accents: %s" % (head, origt))
    t.add("1", head)
    if tr:
      t.add("tr", tr)

    if origt != str(t):
      notes.append("fix up {{be-adj}} to use new param convention")
      pagemsg("Replaced %s with %s" % (origt, str(t)))
    return True


  headt = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["be-noun", "be-proper noun"] or (
      tn == "head" and getparam(t, "1") == "be" and getparam(t, "2") in ["noun", "proper noun"]
    ):
      if headt:
        pagemsg("WARNING: Encountered headword template without declension: %s" % str(headt))
        process_noun_headt(headt)
        headt = None
      headt = t
    elif tn in ["be-decl-noun", "be-decl-noun-unc", "be-decl-noun-pl"]:
      if not headt:
        pagemsg("WARNING: Encountered declension template without headword: %s" % str(t))
      else:
        process_noun_headt(headt, t)
        headt = None
    elif tn == "rfinfl" and getparam(t, "1") == "be":
      if headt:
        process_noun_headt(headt)
        headt = None
    elif tn == "be-verb":
      process_verb_headt(t)
    elif tn == "be-adj":
      process_adj_headt(t)
  if headt:
    pagemsg("WARNING: Encountered headword template without declension: %s" % str(headt))
    process_noun_headt(headt)

  return str(parsed), notes

parser = blib.create_argparser(u"Clean up be-noun params",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    #default_refs=["Template:be-adj", "Template:be-verb", "Template:be-noun"], edit=True)
    default_cats=["Belarusian proper nouns", "Belarusian nouns"], edit=True)
