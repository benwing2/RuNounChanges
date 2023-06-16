#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import bglib

nouns_to_accents_and_forms = {}

template_to_infl_codes = {
  "indefinite singular of": ["indef", "s"],
  "definite singular of": ["def", "s"],
  "vocative singular of": ["voc", "s"],
  "indefinite plural of": ["indef", "p"],
  "definite plural of": ["def", "p"],
  "vocative plural of": ["voc", "p"],
}

def snarf_noun_accents_and_forms(noun, orig_pagemsg):
  global args
  pagetitle = bglib.remove_accents(noun)
  if pagetitle in nouns_to_accents_and_forms:
    return nouns_to_accents_and_forms[pagetitle]
  def pagemsg(txt):
    orig_pagemsg("Noun %s: %s" % (noun, txt))
  page = pywikibot.Page(site, pagetitle)
  parsed = blib.parse(page)
  lemma = None
  for t in parsed.filter_templates():
    if tname(t) in ["bg-noun", "bg-proper noun"]:
      if lemma:
        pagemsg("WARNING: Saw two {{bg-noun}} invocations without intervening {{bg-ndecl}}: %s" % str(t))
      lemma = getparam(t, "1")
      if not lemma:
        pagemsg("WARNING: Missing headword in noun: %s" % str(t))
        continue
      if bglib.needs_accents(lemma):
        pagemsg("WARNING: Noun %s missing an accent: %s" % (lemma, str(t)))
        lemma = False
        continue
    if tname(t) == "bg-ndecl":
      if lemma is False:
        pagemsg("WARNING: Skipping %s because noun missing an accent" % str(t))
        continue
      if lemma is None:
        pagemsg("WARNING: Skipping %s because no preceding {{bg-noun}}" % str(t))
        continue
      if pagetitle in nouns_to_accents_and_forms:
        pagemsg("WARNING: Saw two {{bg-ndecl}} on the same page: %s" % str(t))
        nouns_to_accents_and_forms[pagetitle] = (None, None)
        return (None, None)
      generate_template = re.sub(r"^\{\{bg-ndecl\|", "{{bg-generate-noun-forms|", str(t))
      def expand_text(tempcall):
        return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
      generate_result = expand_text(generate_template)
      if not generate_result:
        nouns_to_accents_and_forms[pagetitle] = (None, None)
        return (None, None)
      nouns_to_accents_and_forms[pagetitle] = (lemma, blib.split_generate_args(generate_result))
  if pagetitle in nouns_to_accents_and_forms:
    return nouns_to_accents_and_forms[pagetitle]
  pagemsg("WARNING: Couldn't find both lemma and declension")
  nouns_to_accents_and_forms[pagetitle] = (None, None)
  return (None, None)

def format_forms(forms):
  return "|".join("%s=%s" % (k, v) for k, v in sorted(forms.items()))

def infls_to_slot(infls):
  if infls == ["def", "sbjv", "s"]:
    return "def_sub_sg"
  elif infls == ["def", "objv", "s"]:
    return "def_obj_sg"
  elif infls == ["def", "s"]:
    return "def_sg"
  elif infls == ["voc", "s"]:
    return "voc_sg"
  elif infls == ["indef", "p"]:
    return "ind_pl"
  elif infls == ["def", "p"]:
    return "def_pl"
  elif infls == ["voc", "p"]:
    return "voc_pl"
  elif infls == ["count", "form"]:
    return "count"
  else:
    return None

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  for t in parsed.filter_templates():
    if tname(t) == "bg-noun-form":
      origt = str(t)
      must_continue = False
      for param in t.params:
        if pname(param) not in ["1", "2", "3", "head"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pname(param), str(param.value), origt))
          must_continue = True
          break
      if must_continue:
        continue
      rmparam(t, "1")
      rmparam(t, "2")
      head = getparam(t, "head")
      rmparam(t, "head")
      g = getparam(t, "3")
      rmparam(t, "3")
      blib.set_template_name(t, "head")
      t.add("1", "bg")
      t.add("2", "noun form")
      if head:
        t.add("head", head)
      else:
        if bglib.needs_accents(pagetitle):
          pagemsg("WARNING: Can't add head= to {{bg-noun-form}} missing it because pagetitle is multisyllabic: %s" %
              str(t))
        else:
          t.add("head", pagetitle)
      if g:
        t.add("g", g)
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("replace {{bg-noun-form}} with {{head|bg|noun form}}")

  headt = None
  saw_infl_after_head = False
  saw_headt = False
  saw_inflt = False
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    saw_infl = False
    already_fetched_forms = False
    if tn == "head" and getparam(t, "1") == "bg" and getparam(t, "2") == "noun form":
      saw_headt = True
      if headt and not saw_infl_after_head:
        pagemsg("WARNING: Saw two head templates %s and %s without intervening inflection" % (
          str(headt), origt))
      saw_infl_after_head = False
      headt = t
    if tn == "bg-noun form of":
      saw_inflt = True
      if not headt:
        pagemsg("WARNING: Saw {{bg-noun form of}} without head template: %s" % origt)
        continue
      must_continue = False
      for param in t.params:
        if pname(param) not in ["1", "2", "3", "noun"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pname(param), str(param.value), origt))
          must_continue = True
          break
      if must_continue:
        continue
      saw_infl_after_head = True
      noun = getparam(t, "noun")
      if not noun:
        pagemsg("WARNING: Didn't see noun=: %s" % origt)
        continue
      infls = []
      param2 = getparam(t, "2")
      if param2 == "indefinite":
        infls.append("indef")
      elif param2 == "definite":
        infls.append("def")
      elif param2 == "vocative":
        infls.append("voc")
      elif param2:
        pagemsg("WARNING: Saw unrecognized 2=%s: %s" % (param2, origt))
        continue
      param3 = getparam(t, "3")
      if param3 == "subject":
        infls.append("sbjv")
      elif param3 == "object":
        infls.append("objv")
      elif param3:
        pagemsg("WARNING: Saw unrecognized 3=%s: %s" % (param3, origt))
        continue
      param1 = getparam(t, "1")
      if param1 == "singular":
        infls.append("s")
      elif param1 == "plural":
        infls.append("p")
      elif param1 == "count":
        infls.extend(["count", "form"])
      elif param1 == "vocative":
        infls.extend(["voc", "s"])
      else:
        pagemsg("WARNING: Saw unrecognized 1=%s: %s" % (param1, origt))
        continue
      blib.set_template_name(t, "inflection of")
      del t.params[:]
      t.add("1", "bg")
      lemma, forms = snarf_noun_accents_and_forms(noun, pagemsg)
      if not lemma:
        pagemsg("WARNING: Unable to find accented equivalent of %s: %s" % (noun, origt))
        t.add("2", noun)
      else:
        t.add("2", lemma)
      t.add("3", "")
      for i, infl in enumerate(infls):
        t.add(str(i + 4), infl)
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("convert {{bg-noun form of}} to {{inflection of}}")
      tn = tname(t)
      saw_infls = infls_to_slot(infls)
      already_fetched_forms = True
      if not saw_infls:
        pagemsg("WARNING: Unrecognized inflections %s: %s" % ("|".join(infls), origt))
    elif tn == "inflection of" and getparam(t, "1") == "bg":
      saw_inflt = True
      infls = []
      i = 4
      while True:
        infl = getparam(t, str(i))
        if not infl:
          break
        infls.append(infl)
        i += 1
      saw_infls = infls_to_slot(infls)
      if not saw_infls:
        if "vnoun" in infls:
          pagemsg("Skipping verbal noun inflection %s: %s" % ("|".join(infls), origt))
        elif "part" in infls:
          pagemsg("Skipping participle inflection %s: %s" % ("|".join(infls), origt))
        else:
          pagemsg("WARNING: Unrecognized inflections %s: %s" % ("|".join(infls), origt))
    elif tn == "definite singular of" and getparam(t, "1") == "bg":
      saw_inflt = True
      saw_infl = "def_sg"
    elif tn == "indefinite plural of" and getparam(t, "1") == "bg":
      saw_inflt = True
      saw_infl = "ind_pl"
    elif tn == "definite plural of" and getparam(t, "1") == "bg":
      saw_inflt = True
      saw_infl = "def_pl"
    elif tn == "vocative singular of" and getparam(t, "1") == "bg":
      saw_inflt = True
      saw_infl = "voc_sg"
    if saw_infl:
      if not already_fetched_forms:
        noun = getparam(t, "2")
        lemma, forms = snarf_noun_accents_and_forms(noun, pagemsg)
        if not lemma:
          pagemsg("WARNING: Unable to find accented equivalent of %s: %s" % (noun, origt))
          continue
        t.add("2", lemma)
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("replace lemma with accented %s in {{%s}}" % (lemma, tn))
      if saw_infl == "def_sg":
        def_sub_sg = forms.get("def_sub_sg", None)
        def_obj_sg = forms.get("def_obj_sg", None)
        if def_sub_sg != def_obj_sg:
          pagemsg("WARNING: Inflection is def_sg but def_sub_sg %s != def_obj_sg %s" % (
            def_sub_sg, def_obj_sg))
          continue
        form = def_sub_sg
      else:
        form = forms.get(saw_infl, None)
      if not form:
        pagemsg("WARNING: Inflection is %s but couldn't find form among forms: %s" %
            (saw_infl, format_forms(forms)))
        continue
      form = form.split(",")
      filtered_form = [f for f in form if bglib.remove_accents(f) == pagetitle]
      if not filtered_form:
        pagemsg("WARNING: No forms among %s=%s match page title" % (saw_infl, ",".join(form)))
        continue
      form = filtered_form
      existing_form = blib.fetch_param_chain(headt, "head", "head")
      if existing_form:
        must_continue = False
        for f in existing_form:
          if bglib.remove_accents(f) != pagetitle:
            pagemsg("WARNING: Existing head %s doesn't match page title: %s" % (
              f, str(headt)))
            must_continue = True
            break
        if must_continue:
          continue
        needs_accents = [bglib.needs_accents(f) for f in existing_form]
        if any(needs_accents) and not all(needs_accents):
          pagemsg("WARNING: Some but not all existing heads missing accents: %s" %
              str(headt))
          continue
        if not any(needs_accents):
          if existing_form != form:
            pagemsg("WARNING: For inflection %s, existing form(s) %s != new form(s) %s" % (
              saw_infl, ",".join(existing_form), ",".join(form)))
          continue
      origheadt = str(headt)
      blib.set_param_chain(headt, form, "head", "head")
      pagemsg("Replaced %s with %s" % (origheadt, str(headt)))
      notes.append("add accented form %s=%s to {{head|bg|noun form}}" % (saw_infl, ",".join(form)))

  if saw_headt and not saw_inflt:
    pagemsg("WARNING: Saw head template %s but no inflection template" % str(headt))

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in template_to_infl_codes and getparam(t, "1") == "bg":
      must_continue = False
      for param in t.params:
        if pname(param) not in ["1", "2"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pname(param), str(param.value), origt))
          must_continue = True
          break
      if must_continue:
        continue
      infl_codes = template_to_infl_codes[tn]
      blib.set_template_name(t, "inflection of")
      t.add("3", "")
      for i, infl in enumerate(infl_codes):
        t.add(str(i + 4), infl)
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("convert {{%s}} to {{inflection of}}" % tn)

  return str(parsed), notes

parser = blib.create_argparser(u"Convert Bulgarian noun forms to standard templates",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Bulgarian noun forms"], edit=True)
