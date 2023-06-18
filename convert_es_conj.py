#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json

import blib
from blib import getparam, rmparam, getrmparam, tname, pname, msg, errandmsg, site

es_conv_verb = {
  "-ar": {
    "andar": "<>",
    "dar": "<>",
    "errar": "<ye[Spain],+[Latin America]>",
    "estar": "<>",
    "jugar": "<ue>",
    "-car": "<>",
    u"-car i-í": u"<í>",
    "-car o-ue": "<ue>",
    "-gar": "<>",
    "-gar e-ie": "<ie>",
    u"-gar i-í": u"<í>",
    "-gar o-ue": "<ue>",
    "-guar": "<>",
    "-izar": u"<í>",
    "-zar": "<>",
    "-zar e-ie": "<ie>",
    u"-zar go-güe": "<ue>",
    "-zar o-ue": "<ue>",
    "e-ie": "<ie>",
    u"go-güe": "<ue>",
    u"i-í": u"<í>",
    u"i-í unstressed": u"<í>",
    "iar-ar": u"<í,+>",
    "o-hue": "<hue>",
    "o-ue": "<ue>",
    u"u-ú": u"<ú>",
    "imp": "<only3s>",
  },
  "-er": {
    "atardecer": "<only3s>",
    u"atañer": "<only3sp>",
    "caber": "<>",
    "caer": "<>",
    "haber": "<>",
    "hacer": "<>",
    u"hacer i-í": "<>",
    "nacer": "<>",
    "placer": "<>",
    "poder": "<>",
    "-poner": "<>",
    "poner": "<>",
    "poseer": "<>",
    "proveer": "<>",
    "querer": "<>",
    "raer": "<>",
    "roer": "<>",
    "romper": "<>",
    "saber": "<>",
    "ser": "<>",
    "soler": "<>",
    "tener": "<>",
    "traer": "<>",
    "valer": "<>",
    "ver": "<>",
    u"ver e-é": "<>",
    "yacer": "<>",
    "-cer": "<>",
    "-cer o-ue": "<ue>",
    "-eer": "<>",
    "-ger": "<>",
    "-olver": "<>",
    u"-ñer": "<>",
    "c-zc": "<>",
    "e-ie": "<ie>",
    "o-hue": "<hue>",
    "o-ue": "<ue>",
    "-tener": "<>",
  },
  "-ir": {
    "asir": "<>",
    "aterir": "<no_pres_stressed>",
    "concernir": "<ie.only3sp>",
    "decir": "<>",
    "bendecir": "<>",
    "maldecir": "<>",
    "manumitir": "<>",
    "predecir": "<>",
    "redecir": "<>",
    "elegir": "<>",
    "erguir": "<i,ye-i>",
    "imprimir": "<>",
    "morir": "<>",
    "pudrir": "<>",
    "ir": "<>",
    "rehuir": u"<ú>",
    "salir": "<>",
    "sustituir": "<>",
    "-venir": "<>",
    "venir": "<>",
    "-brir": "<>",
    "-cir": "<>",
    "-ducir": "<>", 
    "-egir": "<i>",
    "-gir": "<>",
    "-guir": "<>",
    "-guir (e-i)": "<i>",
    u"-güir": "<>",
    "-quir": "<>",
    "-scribir": "<>",
    "-uir": "<>",
    "-uir unstressed": "<>",
    u"-ñir": "<>",
    u"-ñir e-i": "<i>",
    "c-zc": "<>",
    "e-i": "<i>",
    "e-ie": "<ie>",
    "e-ie-i": "<ie-i>",
    "i-ie": "<ie>",
    u"i-í": u"<í>",
    "o-ue": "<ue-u>",
    u"u-ú": u"<ú>",
  },
  u"-ír": {
    u"embaír": "<no_pres_stressed>",
    u"oír": "<>",
    u"reír": u"<í>",
    u"-eír": u"<í>",
    u"freír": "<>",
    u"refreír": "<>",
  },
}

def generate_old_verb_forms(template, errandpagemsg, expand_text, include_combined):
  generate_template = re.sub(r"\}\}$", "|json=1}}", template)
  #errandpagemsg("generate_template: %s" % generate_template)
  result = expand_text(generate_template)
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  args = {}
  forms = json.loads(result)
  for k, v in forms.iteritems():
    for form_template in v:
      t = list(blib.parse_text(form_template).filter_templates())[0]
      def getp(param):
        return getparam(t, param)
      tn = tname(t)
      if tn != "es-verb form of":
        errandpagemsg("WARNING: Unrecognized verb form template: " % str(t))
        return None
      mood = getp("mood")
      tense = getp("tense")
      if mood == "gerund":
        pref = "gerund"
      elif mood == "past participle":
        number = getp("number")
        gender = getp("gender")
        pref = "pp_" + gender + number
      elif tense == "present" and mood == "indicative":
        pref = "pres"
      elif tense == "present" and mood == "subjunctive":
        pref = "pres_sub"
      elif tense == "imperfect" and mood == "indicative":
        pref = "impf"
      elif tense == "imperfect" and mood == "subjunctive":
        if getp("sera") == "ra":
          pref = "impf_sub_ra"
        else:
          pref = "impf_sub_se"
      elif tense == "preterite":
        pref = "pret"
      elif tense == "future" and mood == "indicative":
        pref = "fut"
      elif tense == "future" and mood == "subjunctive":
        pref = "fut_sub"
      elif tense == "conditional":
        pref = "cond"
      elif mood == "imperative":
        if getp("sense") == "affirmative":
          pref = "imp"
        else:
          continue
      else:
        errandpagemsg("WARNING: Unrecognized template args: %s" % str(t))
        return None
      person = getp("person")
      if person:
        number = getp("number")
        formal = getp("formal")
        voseo = getp("voseo")
        if formal == "y":
          if mood == "imperative":
            if person != "2":
              errandpagemsg("WARNING: Unrecognized template args for imperative: %s" % str(t))
              return None
            person = "3"
          else:
            continue
        suffix = person + number + ("v" if voseo else "")
        key = pref + "_" + suffix
      else:
        key = pref

      if key in args:
        args[key] += "," + k
      else:
        args[key] = k

  if include_combined:
    generate_combined_template = re.sub(r"\}\}$", "|json_combined=1}}", template)
    #errandpagemsg("generate_combined_template: %s" % generate_combined_template)
    result = expand_text(generate_combined_template)
    if not result:
      errandpagemsg("WARNING: Error generating forms, skipping")
      return None
    forms = json.loads(result)
    for k, v in forms.iteritems():
      clitic, slot, base_form = v
      if slot == "imp_i2s":
        slot = "imp_2s"
      elif slot == "imp_f2s":
        slot = "imp_3s"
      elif slot == "imp_1p":
        slot = "imp_1p"
      elif slot == "imp_i2p":
        slot = "imp_2p"
        # For some weird reason, the old code generates both amados (incorrect) and amaos (correct)
        # and only displays the latter
        if clitic == "os" and k.endswith("dos"):
          continue
      elif slot == "imp_f2p":
        slot = "imp_3p"
      elif slot == "inf":
        slot = "infinitive"
      elif slot == "ger":
        slot = "gerund"
      else:
        errandpagemsg("WARNING: Unrecognized slot %s: %s" % (slot, result))
        return None

      slot += "_comb_" + clitic
      if slot in args:
        args[slot] += "," + k
      else:
        args[slot] = k

  return args

old_es_conj_templates = {
  "es-conj-ar",
  "es-conj-er",
  "es-conj-ir",
  u"es-conj-ír",
}

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg, include_combined):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def sort_multiple(v):
    return ",".join(sorted(v.split(",")))

  def generate_old_forms():
    args = generate_old_verb_forms(origt, errandpagemsg, expand_text, include_combined)
    if args:
      args["infinitive"] = pagetitle
    args = {k: sort_multiple(v) for k, v in args.iteritems()}
    return args

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{es-conj", "{{User:Benwing2/es-generate-verb-forms", newt)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    args = blib.split_generate_args(new_result)
    args = {k: v for k, v in args.iteritems() if not k.startswith("neg_") and k != "infinitive_linked"}
    args = {k: sort_multiple(v) for k, v in args.iteritems()}
    return args

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg, already_split=True, show_all=True)

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg, notes):
  global args
  origt = str(t)
  tn = tname(t)
  m = re.search(r"^es-conj(-.*)$", tn)
  if not m:
    pagemsg("WARNING: Something wrong, can't parse verb conj template name: %s" % tn)
    return None
  conj_suffix = m.group(1)
  if conj_suffix not in es_conv_verb:
    pagemsg("WARNING: Something wrong, unrecognized verb conj suffix %s: %s" % (conj_suffix, str(t)))
    return None
  old_conj_type = getparam(t, "p")
  if not old_conj_type:
    arg = "<>"
  elif pagetitle.endswith("cocer"):
    # special-case cocer, which we treat as irregular (cocer -> cuezo not #cuezco) but would
    # otherwise have <ue>
    arg = "<>"
  elif old_conj_type not in es_conv_verb[conj_suffix]:
    pagemsg("WARNING: Unrecognized verb conj %s: %s" % (old_conj_type, str(t)))
    return None
  else:
    arg = es_conv_verb[conj_suffix][old_conj_type]
  ref = getparam(t, "ref")
  combined = getparam(t, "combined")
  for param in t.params:
    pn = pname(param)
    if pn not in ["p", "1", "2", "ref", "combined"]:
      pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, str(param.value), str(t)))
      return None
  if arg == "<>":
    arg = ""
  if ref and not pagetitle.endswith("se"):
    arg = pagetitle + "se" + arg
  elif not ref and pagetitle.endswith("se"):
    pagemsg("WARNING: Reflexive verb without reflexive conjugation, skipping: %s" % str(t))
    return None
  # Erase all params
  del t.params[:]
  if arg:
    t.add("1", arg)
  if not combined:
    t.add("nocomb", "1")
  blib.set_template_name(t, "es-conj")
  pagemsg("Replaced %s with %s" % (origt, str(t)))
  is_same = compare_new_and_old_templates(origt, str(t), pagetitle, pagemsg, errandpagemsg, combined)
  if is_same:
    pass
  elif args.ignore_differences:
    pagemsg("WARNING: Comparison doesn't check out, still replacing due to --ignore-differences")
  else:
    return None
  notes.append("converted {{%s|...}} to %s" % (tn, str(t)))
  return t

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in old_es_conj_templates:
      if convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg, notes):
        pass
      else:
        return

  return str(parsed), notes

parser = blib.create_argparser("Convert Spanish verb conj templates to new form",
    include_pagefile=True)
parser.add_argument("--ignore-differences", action="store_true", help="Convert even when new-old comparison doesn't check out. BE CAREFUL!")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Spanish verbs"], edit=True)
