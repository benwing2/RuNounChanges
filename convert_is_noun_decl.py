#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json, unicodedata

import blib
from blib import getparam, rmparam, getrmparam, tname, pname, msg, errandmsg, site

# Rules for converting old declension templates to new ones:
# 1. Masculines:
# 1a. nom in -ur:
#    - those in -ur with gen -s, pl -ar look like this:
#      {{is-decl-noun-m-s1|h|e|st|ur|i=i}}
#      - 4=ur; u-mutation happens automatically if 2=a
#      - i=i specifies dati/i
#      - i=i? specifies dati/i:-, but is also used for dati/-:i
#      - i=i- specifies dati/-
#      - i=?i specifies dati:-/i, but is also used for dat-:i/i
#      - i=? specifies dati:-/i:-; but is also used for dati:-/-:i, etc.
#      - i=?- specifies dati:-/-, but is also used for dat-:i/-
#      - i=[unspecified] specifies dat-/-; except when 2=a and 3=g, in which case dati/i along with umlaut
#      - (NOTE: All of the above are frequently wrongly used and need manual review)
#    - those in -ur with gen -s, sg-only look like this:
#      {{is-decl-noun-m-s1|h|a|mp|ur|i=i|pl=-}}
#    - those in -ur with gen -s, sg-only, indef-only look like this:
#      {{is-decl-noun-m-s2|Nor|e|g|i=i|pl=-|def=-}} [THIS COULD USE s1 as well]
#    - those in -ur with gens:ar or genar:s, pl -ar look like this:
#      {{is-decl-noun-m-s1|kr|a|ft|ur|i=i|ar=?}}
#    - those in -ur with genar, pl -ar look like this:
#      {{is-decl-noun-m-s1|gr|au|t|ur|ar=ar|i=?-}}
#    - those in -ur with v-insertion look like this:
#      {{is-decl-noun-m-s1|s|ö|ng|ur|v=v}}
#    - those in -ur with gen -s, pl -ir look like this:
#      {{is-decl-noun-m-s2|bl|u|nd|i=i}}
#      {{is-decl-noun-m-s2|s|e|l|ur|i=i}}
#      {{is-decl-noun-m-s2|k|i|pp}}
#      {{is-decl-noun-m-s2|s|jó|ð|i=i?}}
#    - those in -ur with gen -s, pl -ir, i-mut in dat sg and nom/acc pl look like this:
#      {{is-decl-noun-m-s3|sp|ó|n|u=u|s=s}}
#    - those in -ur with gen -s, pl -ir with j-insertion look like this:
#      {{is-decl-noun-m-s2|sm|e|kk|j=?}}
#      - this is supposed to have optional j-insertion but the code to do this seems not written
#    - those in -ur with gen -ar, pl -ir look like this:
#      {{is-decl-noun-m-s3|skuldun|au|t|u=u}} [THIS ONE IS WRONG]
#      {{is-decl-noun-m-s3|hl|u|t}}
#      - NOTE: empty 4th param would be needed to not get -ur in nominative
#    - those in -ur with gen -ar, pl -ir, uumut to [[mörkuðum]] look like this:
#      {{is-decl-noun-m-s3|m|a|rk|a|ð}}
#    - those in -ur with gen -ar, pl -ir, unuumut to [[mánaðar]] look like this (lemma [[mánuður]]):
#      {{is-decl-noun-m-s3|m|á|n|a|ð|u=u}}
#    - those in -ur with gen -ar, pl -ir, i-mut in dat sg and nom/acc pl look like this:
#      {{is-decl-noun-m-s3|h|á|tt|u=u}}
#      {{is-decl-noun-m-s3|s|o|n|u=u}}
#    - those in -ur with gen -ar, pl -ir, unumut to e.g. katt- followed by i-mut to e.g. kett- look like this (lemma [[köttur]]):
#      {{is-decl-noun-m-s3|k|a|tt|u=u}}
#      {{is-decl-noun-m-s3|k|a|kk|u=u}} (lemma [[kökkur]])
#      {{is-decl-noun-m-s3|f|ja|rð|u=u}} (lemma [[fjörður]])
#      {{is-decl-noun-m-s3|k|ja|l|u=u}} (lemma [[kjölur]])
#    - those in -ur with gen -s/ar, pl -ir look like this:
#      {{is-decl-noun-m-s2|br|a|g|ar=?}}
#    - those in -ur with gen -s/ar, pl -ir, j-insertion look like this:
#      {{is-decl-noun-m-s2|b|e|ð|i=i?|j=j|ar=?}}
#      {{is-decl-noun-m-s2|b|e|kk|j=j|ar=?}}
#    - those in -ur with gen -s, pl -ar/-ir like [[gígur]] "crater" need two declension tables:
#      {{is-decl-noun-m-s2|g|í|g|ur}}
#      {{is-decl-noun-m-s1|g|í|g|ur}}
#    - proper names with gen -ar:
#      {{is-decl-noun-m-s1|B|á|rð|ur|i=i|ar=ar|def=-|pl=-}}
#    - those pl-only in -ar look like this:
#      {{is-decl-noun-m-s1|tónl|ei|k|sg=-}}
# 1b. empty nominative:
#    - gen -s, pl -ar:
#      {{is-decl-noun-m-s1|l|í|kjör}}
#      {{is-decl-noun-m-s1|m|au|r}}
#      {{is-decl-noun-m-s1||au|r|i=?-}}
#      {{is-decl-noun-m-s1|kl|á|r}}
#      {{is-decl-noun-m-s1|b|jó|r}}
#      {{is-decl-noun-m-s1|b|o|tn|i=i}}
#      {{is-decl-noun-m-s1|bisk|u|p|i=i}}
#      {{is-decl-noun-m-s1|str|æ|tó|ur=-|i=-}}
#    - gen -s, sg-only:
#      {{is-decl-noun-m-s1|s|au|r|pl=-}}
#    - gen lost after -Cs or -x, pl -ar:
#      {{is-decl-noun-m-s1|f|o|ss|i=i}}
#      {{is-decl-noun-m-s1|l|a|x|i=i}}
#      - happens automatically
#    - proper names with gen -ar:
#      {{is-decl-noun-m-s1|Neptún|u|s|i=i|ar=ar|pl=-|def=-}}
#    - gen -s, pl -ir:
#      {{is-decl-noun-m-s2|g|u|ð||i=i}}
#      - NOTE: empty 4th param is needed (?!) because otherwise you get 'guður' in nominative
#    - gen -s, pl -ir, j-insertion in plural:
#      {{is-decl-noun-m-s2|h|e|r||j=j}}
#      - NOTE: empty 4th param is needed (?!) because otherwise you get 'herur' in nominative
#    - gen -s/ar, pl -ir, j-insertion in plural:
#      {{is-decl-noun-m-s2|bl|æ||r|j=j|ar=?}}
#    - gen -ar, pl -ir, unumut to e.g. knarr- followed by i-mut to e.g. knerr- (lemma [[knörr]]):
#      {{is-decl-noun-m-s3|kn|a|rr|u=u|ur=}}
#      {{is-decl-noun-m-s3||a|rn|u=u}}
#      {{is-decl-noun-m-s3|b|ja|rn|u=u}}
# 1c. empty nominative in -ur that's part of the stem and contracts:
#    - dati/i:
#      {{is-decl-noun-m-s1|b|a|kst|u|r}}
#      - note 5th param; i/i is the default when contracts
#    - dati/i, sg-only:
#      {{is-decl-noun-m-s1|far|a|ng|u|r|pl=-}}
#    - dati/i, gen -s/ar:
#      {{is-decl-noun-m-s1|hl|á|t|u|r|ar=?}}
# 1d. empty nominative in -ar that's part of the stem and contracts:
#      {{is-decl-noun-m-s1|h|a|m|a|r}}
# 1e. empty nominative in -ar that's part of the stem and doesn't contract:
#    - gen in -s:
#      {{is-decl-noun-m-s1|rad|a|r}}
#    - gen in -ar, sg-only:
#      {{is-decl-noun-m-s3|m|a|r|ur=|i=?|pl=-}}
#    - gen in -s, pl in -ar:
#      {{is-decl-noun-m-s1|m|a|r|i=?}}
#    - gen in -s, pl in -ir:
#      {{is-decl-noun-m-s2|m|a|r||i=?}}
# 1f. nominative is -l:
#    - not preceded by a/i/u:
#      {{is-decl-noun-m-s1|b|í|l|l}}
#    - preceded by a/i/u, with contraction:
#      {{is-decl-noun-m-s1|g|a|ff|a|l}}
#    - preceded by a/i/u, without contraction:
#      {{is-decl-noun-m-s1|raf|a|l|l}}
#    - names in -kell:
#      {{is-decl-noun-kell|Þor}}
#    - special handling for [[ketill]]:
#      {{is-decl-noun-m-s1|k|a|t|i|l|l}}
#      - 6th param may be being ignored
#    - special handling for [[Ketill]]:
#      {{is-decl-noun-m-s1|K|a|t|i|l}}
#    - special handling for [[Egill]]:
#      {{is-decl-noun-m-s1||A|g|i|l|pl=-|def=-}}
# 1g. nominative is -n:
#    - not preceded by a/i/u:
#      {{is-decl-noun-m-s1|fl|ei|n|n|i=i}}
#    - preceded by a/i/u, with contraction:
#      {{is-decl-noun-m-s1|h|i|m|i|n}}
#    - proper names:
#      {{is-decl-noun-m-s2|Sk|á|n|n|i=i|def=-|pl=-}}
# 1h. nominative is -r:
#    - gen in -s, pl in -ar:
#      {{is-decl-noun-m-s1|h|ó||r}}
#    - gen in -s, pl in -ar, v-insertion in plural:
#      {{is-decl-noun-m-s1|hj|ö|r|v=v}}
#    - gen in -s, pl in -ir:
#      {{is-decl-noun-m-s2|n|á||r}}
#      - note: this wrongly produces two dative plurals, nám/náum, but only náunum in the definite
#      {{is-decl-noun-m-s2|sk|jó||r}}
#      - note: for some reason, this does not produce a dative plural skjóm
#    - gen in -s, pl in -ir, j-insertion in plural:
#      {{is-decl-noun-m-s2|gn|ý||r|j=j}}
#    - gen in -s/ar, pl in -ar:
#      {{is-decl-noun-m-s1|snj|ó||r|ar=?}}
#    - gen in -s/ar, pl in -ir:
#      {{is-decl-noun-m-s2|sj|ó||r|ar=?}}
#      - note: for some reason, this does not produce a dative plural sjóm
#    - gen in -s/ar, pl in -ir, j-insertion in plural:
#      {{is-decl-noun-m-s2|bl|æ||r|j=j|ar=?}}
#    - gen in -s, pl in -var:
#      {{is-decl-noun-m-s1|m|á||r|v=v}}
#      {{is-decl-noun-m-s1|snj|ó||r|ar=ar|v=v}}
#    - gen in -s, sg-only:
#      {{is-decl-noun-m-s2|gl|æ||r|pl=-}}
#      {{is-decl-noun-m-s1|þ|ey||r|pl=-}}
#    - gen in -var, sg-only:
#      {{is-decl-noun-m-s1|sj|á||r|v=v|ar=ar|pl=-}}
#      {{is-decl-noun-m-s3|s|æ|||v|ur=r|pl=-}}
#      - the latter marked as "incorrect use of template, although display is correct (for now)"
#    - gen in -s/var, sg-only:
#      {{is-decl-noun-m-s1|sn|æ||r|v=v|ar=?|i=?-|pl=-}}
#      - this generates dative snævi/snæ
#    - gen in -ar, pl in -ir, j-insertion in plural:
#      {{is-decl-noun-m-s2|b|æ||r|j=j|ar=ar}}
#    - proper name [[Már]]:
#      {{is-decl-noun-m-s1||M|á|r|def=-|pl=-}}






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
    if isinstance(values, str):
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
      for k, v in values.items():
        if key:
          process_nested_forms(key + "_" + k, v)
        else:
          process_nested_forms(k, v)
    else:
      newkey, newval = convert_old_slot_name(key, values)
      if type(newval) is list:
        newval = ",".join(newval)
      else:
        assert isinstance(newval, str)
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
    args = {k: sort_multiple(v).replace("&#32;", " ") for k, v in args.items()}
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
      k: blib.remove_links(unicodedata.normalize("NFC", flatten_values(v))) for k, v in args.items()
      if not re.search("^(neg_|infinitive_|gerund_)", k)
    }
    args = {k: sort_multiple(v) for k, v in args.items()}
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
