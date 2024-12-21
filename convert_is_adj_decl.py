#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json, unicodedata

import blib
from blib import getparam, rmparam, getrmparam, tname, pname, msg, errandmsg, site

slot_mapping = {
  "str_nom_m_s": "str_nom_m",
  "str_nom_f_s": "str_nom_f",
  "str_nom_n_s": "str_nom_n",
  "str_acc_m_s": "str_acc_m",
  "str_acc_f_s": "str_acc_f",
  "str_acc_n_s": "str_nom_n",
  "str_dat_m_s": "str_dat_m",
  "str_dat_f_s": "str_dat_f",
  "str_dat_n_s": "str_dat_n",
  "str_gen_m_s": "str_gen_m",
  "str_gen_f_s": "str_gen_f",
  "str_gen_n_s": "str_gen_n",
  "str_nom_m_p": "str_nom_mp",
  "str_nom_f_p": "str_nom_fp",
  "str_nom_n_p": "str_nom_np",
  "str_acc_m_p": "str_acc_mp",
  "str_acc_f_p": "str_nom_fp",
  "str_acc_n_p": "str_nom_np",
  "str_gen_m_p": "str_gen_p",
  "str_gen_f_p": "str_gen_p",
  "str_gen_n_p": "str_gen_p",
  "str_dat_m_p": "str_dat_p",
  "str_dat_f_p": "str_dat_p",
  "str_dat_n_p": "str_dat_p",
  "wk_nom_m_s": "wk_nom_m",
  "wk_nom_f_s": "wk_nom_f",
  "wk_nom_n_s": "wk_n",
  "wk_acc_m_s": "wk_obl_m",
  "wk_acc_f_s": "wk_obl_f",
  "wk_acc_n_s": "wk_n",
  "wk_dat_m_s": "wk_obl_m",
  "wk_dat_f_s": "wk_obl_f",
  "wk_dat_n_s": "wk_n",
  "wk_gen_m_s": "wk_obl_m",
  "wk_gen_f_s": "wk_obl_f",
  "wk_gen_n_s": "wk_n",
  "wk_nom_m_p": "wk_p",
  "wk_nom_f_p": "wk_p",
  "wk_nom_n_p": "wk_p",
  "wk_acc_m_p": "wk_p",
  "wk_acc_f_p": "wk_p",
  "wk_acc_n_p": "wk_p",
  "wk_gen_m_p": "wk_p",
  "wk_gen_f_p": "wk_p",
  "wk_gen_n_p": "wk_p",
  "wk_dat_m_p": "wk_p",
  "wk_dat_f_p": "wk_p",
  "wk_dat_n_p": "wk_p",
}

def generate_old_adj_forms(template, errandpagemsg, expand_text):
  result = expand_text(template)
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  args = {}

  curdeg = None
  curstate = None
  curnum = None
  curcase = None
  genderind = None
  gender_index_to_code = {0: "m", 1: "f", 2: "n"}
  for line in result.split("\n"):
    m = re.search(r"NavHead.*comparative", line)
    if m:
      curdeg = "comp_"
      curstate = "wk"
      curnum = None
      curcase = None
      genderind = None
      continue
    m = re.search(r"NavHead.*(positive|superlative) \((strong|weak) declension\)", line)
    if m:
      curdeg = "" if m.group(1) == "positive" else "sup_"
      curstate = "str" if m.group(2) == "strong" else "wk"
      continue
    m = re.search(r"NavHead.*weak declension", line)
    if m:
      curdeg = ""
      curstate = "wk"
      continue
    m = re.search(r"^! .*\| (singular|plural)$", line)
    if m:
      curnum = "s" if m.group(1) == "singular" else "p"
      curcase = None
      genderind = None
      continue
    m = re.search(r"^! .*\| '''(nominative|accusative|dative|genitive)'''$", line)
    if m:
      curcase = m.group(1)[0:3]
      genderind = 0
      continue
    m = re.search('<span class="Latn[^<>"]*" lang="is">(.*)</span>', line)
    if m:
      raw_forms = m.group(1)
      forms = re.findall(r"\[\[(.*?)#Icelandic\|\1\]\]", raw_forms)
      if not forms:
        errandpagemsg("WARNING: Couldn't parse line with forms: %s" % line.strip())
        return None
      if curnum is None or curcase is None or genderind is None:
        errandpagemsg("WARNING: Found line with forms before encountering case heading: %s" % line.strip())
        return None
      if genderind >= 3:
        errandpagemsg("WARNING: Found line with too many forms after encountering case heading: %s" % line.strip())
        return None
      this_gender = gender_index_to_code[genderind]
      old_slot = "%s_%s_%s_%s" % (curstate, curcase, this_gender, curnum)
      if old_slot not in slot_mapping:
        errandpagemsg("WARNING: Found unrecognized slot %s: %s" % (old_slot, line.strip()))
        return None
      new_slot = slot_mapping[old_slot]
      key = curdeg + new_slot
      formtext = ",".join(forms)
      if key not in args:
        args[key] = formtext
      elif args[key] != formtext:
        errandpagemsg("WARNING: Clash between supposedly syncretic values %s and %s for slot %s (old slot %s): %s" % (
          args[key], formtext, key, old_slot, line.strip()))
        return None
      genderind += 1
  msg("From %s, returning %s" % (template, args))
  return args

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def sort_multiple(v):
    return ",".join(sorted(v.split(",")))

  def generate_old_forms():
    args = generate_old_adj_forms(origt, errandpagemsg, expand_text)
    if args is None:
      return args
    args = {k: sort_multiple(v) for k, v in args.items()}
    return args

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{is-adecl([|}])", r"{{User:Benwing2/is-adecl\1", newt)
    new_generate_template = re.sub(r"\}\}$", "|json=1}}", new_generate_template)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    raw_args = json.loads(new_result)
    args = raw_args["forms"]
    def flatten_values(values):
      retval = []
      for v in values:
        retval.append(v["form"])
      return ",".join(retval)
    args = {
      k: blib.remove_links(unicodedata.normalize("NFC", flatten_values(v))) for k, v in args.items()
      if not k.endswith("_linked")
    }
    args = {k: sort_multiple(v) for k, v in args.items()}
    return args

  retval = generate_new_forms()
  if retval is None:
    new_forms_for_compare, new_forms = None, {}
  else:
    new_forms = retval
    new_forms_for_compare = new_forms

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms, lambda: new_forms_for_compare,
    pagemsg, errandpagemsg, already_split=True, show_all=True, no_warn_on_mismatch=True), new_forms

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg, notes):
  global args
  origt = str(t)
  tn = tname(t)
  def getp(param):
    return getparam(t, param)
  parts_candidates = [""]
  extra_candidates = [""]
  pos = getp("pos") or getp("posd") # posd=- not supported but found
  comp = getp("comp")
  if tn in ["is-decl-adj-1", "is-decl-adj-2", "is-decl-adj-3"]:
    p1 = getp("1")
    p2 = getp("2")
    p3 = getp("3")
    p4 = getp("4")
    p5 = getp("5")
    imut = tn == "is-decl-adj-2"
    parts = []
    if pos == "-":
      parts.append("-pos")
    else:
      extra_candidates = [".-comp"] if comp == "-" else [".comp"]
      if p5 == "r":
        parts.append("#")
      elif re.search(".glaður$", pagetitle):
        parts_candidates.append(".-pp")
      elif re.search("[áæ]r$", pagetitle):
        parts_candidates.append(".#")
      elif re.search("[^u]r$", pagetitle):
        parts_candidates.append(".##")
      if imut:
        extra_candidates.append(".comp:^")
  elif tn == "is-decl-adj-weak":
    parts = ["weak.-comp"]
  else:
    pagemsg("WARNING: Unrecognized Icelandic old adjective declension template: %s" % origt)
    return None
  pagetitle_for_proper_check = re.sub("^.*[ -](.)", r"\1", pagetitle)
  isproper = pagetitle_for_proper_check[0].isupper()
  def append_parts(part):
    nonlocal parts_candidates
    parts_candidates = [p + part for p in parts_candidates]

  candidate_pref = "".join(parts)
  def generate_candidates(parts_candidates, extra_candidate):
    prefix = candidate_pref + parts_candidates
    return [prefix + extra_candidate]
  candidates = [candidate
    for extra_candidate in extra_candidates
    for parts_candidate in parts_candidates
    for candidate in generate_candidates(parts_candidate, extra_candidate)
  ]
  candidates = [candidate[1:] if candidate.startswith(".") else candidate for candidate in candidates]
  good_candidate = None
  for candidate in candidates:
    newt = "{{is-adecl|%s}}" % candidate
    pagemsg("Considering replacing %s with %s" % (origt, newt))
    is_same, new_forms = compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg)
    if is_same:
      pagemsg("Replaced %s with %s" % (origt, newt))
      good_candidate = candidate
      break
  else: # no break
    pagemsg("WARNING: No candidate checks out, not changing: %s" % origt)
    return None
  notes.append("convert %s to %s" % (origt, newt))
  # Erase all params
  del t.params[:]
  blib.set_template_name(t, "is-adecl")
  t.add("1", good_candidate)
  return t, new_forms

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "is-decl-adj-" not in text:
    return

  parsed = blib.parse_text(text)

  headt = None
  saw_headt = False

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    if tn in ["is-adj", "is-adj/old"]:
      pagemsg("Saw %s" % str(t))
      saw_headt = True
      if headt:
        pagemsg("WARNING: Saw multiple head templates: %s and %s" % (str(headt), str(t)))
        return
      headt = t
    elif tn.startswith("is-decl-adj-"):
      #if not headt:
      #  pagemsg("WARNING: Saw declension template without {{is-adj}} head template: %s" % str(t))
      #  return
      #headt_as_decl_str = re.sub(r"^\{\{is-adj\|", "{{is-ndecl|", str(headt))
      #if str(t) != headt_as_decl_str:
      #  pagemsg("WARNING: Saw head template %s with different params from declension template %s" % (
      #    str(headt), str(t)))
      #  return
      retval = convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg, notes)
      if retval is not None:
        newt, new_forms = retval
        if headt:
          def convert_empty_to_hyphen(val):
            if not val:
              return "-"
            return val
          indec = getparam(headt, "indec")
          head = getparam(headt, "head")
          if indec:
            pagemsg("WARNING: Can't handle indec=%s: headt=%s, newdecl=%s" % (indec, str(headt), str(newt)))
            return
          if head:
            pagemsg("WARNING: Can't handle head=%s: headt=%s, newdecl=%s" % (indec, str(headt), str(newt)))
            return
          headt_comps = blib.fetch_param_chain(headt, "1", "comp")
          headt_sups = blib.fetch_param_chain(headt, "2", "sup")
          headt_pls = blib.fetch_param_chain(headt, ["3", "pl"], "pl")
          headt_comps = convert_empty_to_hyphen(",".join(sorted(headt_comps)))
          headt_sups = convert_empty_to_hyphen(",".join(sorted(headt_sups)))
          new_comps = convert_empty_to_hyphen(new_forms.get("comp_wk_nom_m", ""))
          new_sups = convert_empty_to_hyphen(new_forms.get("sup_str_nom_m", ""))
          if headt_comps != "-" and headt_comps != new_comps:
            pagemsg("WARNING: Head comparative(s) %s don't match new decl comparative(s) %s: head=%s, newdecl=%s" % (
              headt_comps, new_comps, str(headt), str(newt)))
            return
          if headt_sups != "-" and headt_sups != new_sups:
            pagemsg("WARNING: Head superlative(s) %s don't match new decl superlative(s) %s: head=%s, newdecl=%s" % (
              headt_sups, new_sups, str(headt), str(newt)))
            return
          orig_headt = str(headt)
          headtn = tname(headt)
          if headtn.endswith("/old"):
            headtn = re.sub("/old$", "", headtn)
            blib.set_template_name(headt, headtn)
          # Erase all params
          del headt.params[:]
          headt.add("1", "@@")
          #if pagetitle in manual_decls:
          #  headt.add("1", manual_decls[pagetitle])
          notes.append("convert %s to %s" % (orig_headt, str(headt)))
      headt = None

  #if not saw_headt:
  #  pagemsg("WARNING: Didn't see {{is-adj}} head template")
  #  return

  return str(parsed), notes

parser = blib.create_argparser("Convert Icelandic adjective decl templates to new form",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  default_cats=["Icelandic adjectives"], edit=True, stdin=True)
