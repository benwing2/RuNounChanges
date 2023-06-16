#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  headt = None
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["de-verb-old", "de-verb-strong", "de-verb-weak"] or tn == "head" and getparam(t, "1") == "de" and getparam(t, "2") == "verb":
      if headt:
        pagemsg("WARNING: Encountered headword twice without declension: old %s, current %s" % (str(headt), str(t)))
        return
      headt = t
      headtn = tn
    if tn == "de-conj":
      if not headt:
        pagemsg("WARNING: Encountered conj without headword: %s" % str(t))
        return
      param4_ignorable = False
      if getparam(headt, "4") in ["h", "haben", "s", "sein"]:
        param4_ignorable = True
      for param in headt.params:
        pn = pname(param)
        pv = str(param.value)
        if not pv:
          continue
        if headtn == "head":
          allowed_params = ["1", "2", "head"]
        elif headtn == "de-verb-weak":
          allowed_params = ["1", "2", "3", "auxiliary", "cat"]
        elif headtn == "de-verb-strong":
          allowed_params = ["1", "2", "3", "class", "class 2", "pres 2", "pres 2 qual", "past 2", "past 2 qual",
            "past participle 2", "past participle 2 qual", "past subjunctive", "past subjunctive 2",
            "past subjunctive 2 qual", "auxiliary", "cat"]
        else:
          allowed_params = ["head"]
        if param4_ignorable:
          allowed_params.append("4")
        if pn not in allowed_params:
          pagemsg("WARNING: Encountered unknown param %s=%s in %s" % (pn, pv, str(headt)))
          return
      def canonicalize_existing(forms):
        forms = [re.sub(" '*or'* ", ",", form) for form in forms]
        forms = [splitform for form in forms for splitform in form.split(",")]
        return [blib.remove_links(form) for form in forms if form]
      def compare(old, new, entities_compared):
        if not old:
          return True
        if set(old) != set(new):
          pagemsg("WARNING: Old %s %s disagree with new %s %s: head=%s, decl=%s" % (
            entities_compared, ",".join(old), entities_compared, ",".join(new), str(headt), str(t)))
          return False
        return True
      def fetch_aux():
        aux = getparam(headt, "auxiliary")
        if aux in ["haben", "sein"]:
          aux = [aux]
        elif aux == "both":
          aux = ["haben", "sein"]
        elif not aux:
          aux = []
        else:
          pagemsg("WARNING: Unrecognized auxiliary=%s, skipping: %s" % (aux, str(headt)))
          return None
        if not aux:
          param4 = getparam(headt, "4")
          if param4 in ["h", "haben"]:
            aux = ["haben"]
          elif param4 in ["s", "sein"]:
            aux = ["sein"]
        return aux
      if headtn == "de-verb-weak":
        generate_template = re.sub(r"^\{\{de-conj(?=[|}])", "{{User:Benwing2/de-generate-verb-props", str(t))
        result = expand_text(generate_template)
        if not result:
          continue
        forms = blib.split_generate_args(result)
        pres_3s = canonicalize_existing([getparam(headt, "1")])
        past = canonicalize_existing([getparam(headt, "2")])
        pp = canonicalize_existing([getparam(headt, "3")])
        aux = fetch_aux()
        if aux is None:
          return
        if (not compare(pres_3s, forms.get("pres_3s", "-").split(","), "pres 3sgs") or
            not compare(past, forms.get("pret_3s", "-").split(","), "pasts") or
            not compare(pp, forms.get("perf_part", "-").split(","), "pp's") or
            not compare(aux, forms.get("aux", "-").split(","), "auxes")):
          headt = None
          continue
      if headtn == "de-verb-strong":
        generate_template = re.sub(r"^\{\{de-conj(?=[|}])", "{{User:Benwing2/de-generate-verb-props", str(t))
        result = expand_text(generate_template)
        if not result:
          continue
        forms = blib.split_generate_args(result)
        pres_3s = canonicalize_existing([getparam(headt, "1"), getparam(headt, "pres 2")])
        past = canonicalize_existing([getparam(headt, "2"), getparam(headt, "past 2")])
        pp = canonicalize_existing([getparam(headt, "3"), getparam(headt, "past participle 2")])
        past_subj = canonicalize_existing([getparam(headt, "past subjunctive"), getparam(headt, "past subjunctive 2")])
        clazz = canonicalize_existing([getparam(headt, "class"), getparam(headt, "class 2")])
        aux = fetch_aux()
        if aux is None:
          return
        if (not compare(pres_3s, forms.get("pres_3s", "-").split(","), "pres 3sgs") or
            not compare(past, forms.get("pret_3s", "-").split(","), "pasts") or
            not compare(pp, forms.get("perf_part", "-").split(","), "pp's") or
            not compare(past_subj, forms.get("subii_3s", "-").split(","), "past subjs") or
            not compare(aux, forms.get("aux", "-").split(","), "auxes") or
            not compare(clazz, forms.get("class", "-").split(","), "classes")):
          headt = None
          continue

      del headt.params[:]
      blib.set_template_name(headt, "de-verb")
      arg1 = getparam(t, "1")
      if arg1:
        headt.add("1", arg1)
      notes.append("replace {{%s|...}} with new-style {{de-verb%s}}" % (headtn == "head" and "head|de|verb" or headtn,
        (arg1 and "|" + arg1 or "")))
      headt = None

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert German verb headwords to use new {{de-verb}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_cats=["German verbs"], edit=True, stdin=True)
