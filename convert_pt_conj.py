#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json, unicodedata

import blib
from blib import getparam, rmparam, getrmparam, tname, pname, msg, errandmsg, site

def convert_old_slot_name(slot, values):
  slot = slot.replace("_alt", "")
  slot = re.sub("_plur_([123])", r"_\1p", slot)
  slot = re.sub("_sing_([123])", r"_\1s", slot)
  slot = re.sub("_plur_([mf])", r"_\1p", slot)
  slot = re.sub("_sing_([mf])", r"_\1s", slot)
  slot = re.sub("^indi_pres_", "pres_", slot)
  slot = re.sub("^indi_impf_", "impf_", slot)
  slot = re.sub("^indi_futu_", "fut_", slot)
  slot = re.sub("^indi_cond_", "cond_", slot)
  slot = re.sub("^indi_pret_", "pret_", slot)
  slot = re.sub("^indi_plpf_", "plup_", slot)
  slot = re.sub("^infn_pers_", "pers_inf_", slot)
  slot = re.sub("^infn_impe$", "infinitive", slot)
  slot = re.sub("^part_pres$", "gerund", slot)
  slot = re.sub("^part_past", "pp", slot)
  slot = re.sub("^long_part_past", "pp", slot)
  slot = re.sub("^short_part_past", "short_pp", slot)
  slot = re.sub("^subj_pres_", "pres_sub_", slot)
  slot = re.sub("^subj_impf_", "impf_sub_", slot)
  slot = re.sub("^subj_futu_", "fut_sub_", slot)
  slot = re.sub("^impe_affr_", "imp_", slot)
  slot = re.sub("^impe_negt_", "neg_imp_", slot)
  if "_obsolete" in slot:
    slot = slot.replace("_obsolete", "")
    if isinstance(values, basestring):
      values += "[superseded]"
    else:
      assert type(values) == list
      values = [v + "[superseded]" for v in values]
  if "neg_imp" in slot or not values:
    return None, values
  else:
    return slot, values

def generate_old_verb_forms(template, errandpagemsg, expand_text):
  generate_template = re.sub(r"^\{\{pt-conj\|", "{{User:Benwing2/pt-conj-old-json|", template)
  #errandpagemsg("generate_template: %s" % generate_template)
  result = expand_text(generate_template)
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  args = {}

  def process_nested_forms(key, values):
    if type(values) is dict:
      for k, v in values.iteritems():
        if key:
          process_nested_forms(key + "_" + k, v)
        else:
          process_nested_forms(k, v)
    else:
      newkey, newval = convert_old_slot_name(key, values)
      if type(newval) is list:
        newval = ",".join(newval)
      else:
        assert isinstance(newval, basestring)
      if newkey is not None:
        existing = args.get(newkey, "")
        args[newkey] = existing + "," + newval if existing else newval

  forms = json.loads(result)

  process_nested_forms("", forms["forms"])

  return args

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def sort_multiple(v):
    return ",".join(sorted(v.split(",")))

  def generate_old_forms():
    args = generate_old_verb_forms(origt, errandpagemsg, expand_text)
    if args:
      args["infinitive"] = pagetitle
    args = {k: sort_multiple(v).replace("&#32;", " ") for k, v in args.iteritems()}
    return args

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{pt-conj([|}])", r"{{User:Benwing2/pt-conj\1", newt)
    new_generate_template = re.sub(r"\}\}$", "|json=1}}", new_generate_template)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    args = json.loads(new_result)
    def flatten_values(values):
      retval = []
      for v in values:
        if "footnotes" in v:
          if "[superseded]" in v["footnotes"]:
            retval.append(v["form"] + "[superseded]")
          else:
            retval.append(v["form"])
        else:
          retval.append(v["form"])
      return ",".join(retval)
    args = {
      k: blib.remove_links(unicodedata.normalize("NFC", flatten_values(v))) for k, v in args.iteritems()
      if not re.search("^(neg_|infinitive_|gerund_)", k)
    }
    args = {k: sort_multiple(v) for k, v in args.iteritems()}
    return args

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg, already_split=True, show_all=True)

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg, notes):
  global args
  origt = str(t)
  tn = tname(t)
  if pagetitle in manual_conjs:
    newt = "{{%s|%s}}" % (tn, manual_conjs[pagetitle])
  else:
    newt = "{{%s}}" % tn
  pagemsg("Replaced %s with %s" % (origt, newt))
  is_same = compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg)
  if is_same:
    pass
  elif args.ignore_differences:
    pagemsg("WARNING: Comparison doesn't check out, still replacing due to --ignore-differences")
  else:
    return None
  notes.append("converted {{%s|...}} to %s" % (tn, newt))
  # Erase all params
  del t.params[:]
  if pagetitle in manual_conjs:
    t.add("1", manual_conjs[pagetitle])
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
    if tn == "pt-conj" and getparam(t, "2"):
      if convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg, notes):
        pass
      else:
        return

  return str(parsed), notes

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "pt-verb" not in text:
    return

  parsed = blib.parse_text(text)

  headt = None
  saw_headt = False

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    if tn == "pt-verb" and getp("2"):
      pagemsg("Saw %s" % str(t))
      saw_headt = True
      if headt:
        pagemsg("WARNING: Saw multiple head templates: %s and %s" % (str(headt), str(t)))
        return
      headt = t
    elif tn == "pt-conj" and getp("2"):
      if not headt:
        pagemsg("WARNING: Saw conjugation template without {{pt-verb}} head template: %s" % str(t))
        return
      headt_as_conj_str = re.sub(r"^\{\{pt-verb\|", "{{pt-conj|", str(headt))
      if str(t) != headt_as_conj_str:
        pagemsg("WARNING: Saw head template %s with different params from conjugation template %s" % (
          str(headt), str(t)))
        return
      if convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg, notes):
        orig_headt = str(headt)
        headtn = tname(headt)
        # Erase all params
        del headt.params[:]
        if pagetitle in manual_conjs:
          headt.add("1", manual_conjs[pagetitle])
        notes.append("converted {{%s|...}} to %s" % (headtn, str(headt)))
      headt = None

  if not saw_headt:
    pagemsg("WARNING: Didn't see {{pt-verb}} head template")
    return

  return str(parsed), notes

parser = blib.create_argparser("Convert Portuguese verb conj templates to new form",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File containing manually specified conjugations")
parser.add_argument("--ignore-differences", action="store_true", help="Convert even when new-old comparison doesn't check out. BE CAREFUL!")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

manual_conjs = {}
if args.direcfile:
  for index, line in blib.iter_items_from_file(args.direcfile):
    if " " not in line:
      msg("WARNING: Line %s: No space in line: %s" % (index, line))
    elif " ||| " in line:
      verb, conj = line.split(" ||| ")
    else:
      verb, conj = line.split(" ", 1)
    if verb in manual_conjs:
      msg("WARNING: Line %s: Saw verb %s twice" % verb)
    else:
      manual_conjs[verb] = conj

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  default_cats=["Portuguese verbs"], edit=True, stdin=True)
