#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site


def snarf_inflections(json_output):
  pres = None
  pret = None
  pp = None
  data = json.loads(json_output)
  for infl in data["inflections"]:
    forms = []
    for formind in range(1, 10):
      if str(formind) in infl:
        formobj = infl[str(formind)]
        if type(formobj) is dict:
          form = formobj["term"]
        else:
          form = formobj
        forms.append(form)
    forms = ",".join(sorted(forms))
    label = infl["label"]
    if label == "first-person singular present":
      pres = forms
    elif label == "first-person singular preterite":
      pret = forms
    elif label == "past participle":
      pp = forms

  args = {}
  if pres:
    args["pres_1s"] = pres
  if pret:
    args["pret_1s"] = pret
  if pp:
    args["pp_ms"] = pp
  return args


def generate_verb_forms(template, errandpagemsg, expand_text):
  generate_template = re.sub(r"\}\}$", "|json=1}}", template)
  generate_template = re.sub(r"^\{\{es-verb", "{{User:Benwing2/es-verb", generate_template)
  #errandpagemsg("generate_template: %s" % generate_template)
  result = expand_text(generate_template)
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  return snarf_inflections(result)


def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def sort_multiple(v):
    return ",".join(sorted(v.split(",")))

  def generate_old_forms():
    return generate_verb_forms(origt, errandpagemsg, expand_text)

  def generate_new_forms():
    return generate_verb_forms(newt, errandpagemsg, expand_text)

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg, already_split=True, show_all=True)


def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "es-verb" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  headt = None

  for t in parsed.filter_templates():
    tn = tname(t)

    if tn == "es-verb":
      if headt:
        pagemsg("WARNING: Saw two {{es-verb}} without {{es-conj}}: %s and %s" % (str(headt), str(t)))
      headt = t
      continue

    if tn == "es-conj":
      if not headt:
        pagemsg("WARNING: Saw {{es-conj}} without {{es-verb}}: %s" % str(t))
        continue

      if getparam(headt, "attn"):
        pagemsg("WARNING: Saw attn=, skipping: %s" % str(headt))
        headt = None
        continue

      if getparam(headt, "new"):
        pagemsg("Saw new=, skipping: %s" % str(headt))
        headt = None
        continue

      new_template = blib.parse_text(str(t))
      newt = list(new_template.filter_templates())[0]
      blib.set_template_name(newt, "es-verb")
      newt.add("new", "1")
      rmparam(newt, "nocomb")

      if compare_new_and_old_templates(str(headt), str(newt), pagetitle, pagemsg, errandpagemsg):
        origt = str(headt)
        del headt.params[:]
        for param in newt.params:
          pn = pname(param)
          pv = str(param.value)
          if pn != "new":
            showkey = param.showkey
            headt.add(pn, pv, showkey=showkey, preserve_spacing=False)

        if origt != str(headt):
          headt.add("new", "1")
          pagemsg("Replaced %s with %s" % (origt, str(headt)))
          notes.append("convert {{es-verb}} to new format compatible with {{es-conj}}")
        else:
          pagemsg("No changes to %s" % str(headt))
      headt = None

  if headt:
    pagemsg("WARNING: Saw {{es-verb}} without {{es-conj}}: %s" % str(headt))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{es-verb}} templates to newest format that mirrors {{es-conj}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Spanish verbs"])
