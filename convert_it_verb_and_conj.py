#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site

AC = u"\u0301"
GR = u"\u0300"

def old_it_conj_to_new_it_conj_key(key):
  key = re.sub("pl$", "p", key)
  key = re.sub("sg$", "s", key)
  key = re.sub("^pres_indc_", "pres", key)
  key = re.sub("^impf_indc_", "imperf", key)
  key = re.sub("^phis_indc_", "phis", key)
  key = re.sub("^futr_indc_", "fut", key)
  key = re.sub("^cond_", "cond", key)
  key = re.sub("^pres_subj_", "sub", key)
  key = re.sub("^impf_subj_", "impsub", key)
  key = re.sub("^impr_", "imp", key)
  if key == "gerund":
    key = "ger"
  if key == "pres_ptc":
    key = "presp"
  if key == "past_ptc":
    key = "pp"
  if key == "infinitive":
    key = "inf"
  if key == "sub123s" or key == "impsub12s":
    return None
  return key

def frob_old_values(key, values):
  retvals = []
  for v in values:
    if v.startswith("non ") or key == "pp" and re.search("[st]osi$", v):
      continue
    if key == "presp" and v.endswith("ntesi"):
      v = v[:-2] # chop off -si
    v = blib.remove_links(v)
    if v not in retvals:
      retvals.append(v)

  # [[esistere]] has esistei but not esistetti in old forms, but new forms have both.
  # Augment the old forms appropriately. FIXME: We should check for the -ett- forms in the new
  # forms before augmenting.
  reg_e_ending = None
  if key == "phis1s":
    reg_e_ending = "ei"
    repl_e_ending = "etti"
  elif key == "phis3s":
    reg_e_ending = u"é"
    repl_e_ending = "ette"
  elif key == "phis3p":
    reg_e_ending = "erono"
    repl_e_ending = "ettero"
  if reg_e_ending:
    reg_e_ending_forms = [v for v in retvals if v.endswith(reg_e_ending)]
    if reg_e_ending_forms:
      for form in reg_e_ending_forms:
        repl_form = re.sub(reg_e_ending + "$", repl_e_ending, form)
        if repl_form not in retvals:
          retvals.append(repl_form)

  return retvals

def generate_old_verb_forms(template, errandpagemsg, expand_text, return_raw=False):
  template = re.sub(r"\}\}$", "|json=1}}", template)
  forms = expand_text(template)
  if not forms:
    errandpagemsg("WARNING: Error generating forms, skipping: %s" % template)
    return None
  forms = json.loads(forms)
  newforms = {}
  for k, v in forms.iteritems():
    k = old_it_conj_to_new_it_conj_key(k)
    if k:
      newv = frob_old_values(k, v)
      if newv:
        newforms[k] = newv
  return newforms

def frob_new_values(values):
  retvals = []
  for v in values:
    form = unicodedata.normalize("NFD", blib.remove_links(v["form"]))
    # Remove non-final accents
    form = re.sub("[" + AC + GR + "](.)", r"\1", form)
    if form not in retvals:
      retvals.append(unicodedata.normalize("NFC", form))
  return retvals

def generate_new_verb_forms(template, errandpagemsg, expand_text, return_raw=False):
  template = re.sub(r"\}\}$", "|json=1}}", template)
  forms = expand_text(template)
  if not forms:
    errandpagemsg("WARNING: Error generating forms, skipping: %s" % template)
    return None
  forms = json.loads(forms)["forms"]
  newforms = {}
  for k, v in forms.iteritems():
    if k.startswith("negimp"):
      continue
    newforms[k] = frob_new_values(v)
  return newforms

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def generate_old_forms():
    return generate_old_verb_forms(origt, errandpagemsg, expand_text)

  def generate_new_forms():
    return generate_new_verb_forms(newt, errandpagemsg, expand_text)

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg, already_split=True, show_all=args.all_diffs)

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "it-verb" not in text:
    return

  parsed = blib.parse_text(text)

  headt = None
  saw_headt = False

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    if tn in ["it-verb-old", "it-verb"]:
      pagemsg("Saw %s" % str(t))
      saw_headt = True
      arg = getp("1")
      if not arg:
        pagemsg("WARNING: Saw {{%s}} without param, skipping: %s" % (tn, str(t)))
        return
      if headt:
        pagemsg("WARNING: Saw multiple head templates: %s and %s" % (str(headt), str(t)))
        return
      headt = t
    elif tn.startswith("it-conj-"):
      if not headt:
        pagemsg("WARNING: Saw conjugation template without {{it-verb-old}}/{{it-verb}} head template: %s" % str(conjt))
        return
      conjt = t
      conjt_str = str(conjt)
      headtn = tname(headt)
      headarg1 = getparam(headt, "1")
      if headtn == "it-verb":
        pass
      elif re.search("ar(e|si)$", pagetitle) and ("." not in headarg1 or "only3s" in headarg1): # including only3sp
        pass
      elif re.search("(rre|ere|are)$", pagetitle):
        headarg1 = re.sub(r"([/\\]).*$", r"\1@", headarg1)
      elif re.search("[ou]rsi$", pagetitle):
        headarg1 = "\\@"
      elif re.search("arsi$", pagetitle):
        headarg1 = "@"
      elif re.search("ersi$", pagetitle):
        if "\\" in headarg1:
          headarg1 = "\\@"
        else:
          headarg1 = "/@"
      else:
        pagemsg("WARNING: Can't handle verb automatically; head=%s, conj=%s" % (str(headt), str(conjt)))
        return
      conjarg1 = headarg1

      # expand_text() wants a Unicode string.
      newconjt_str = u"{{it-conj|%s}}" % conjarg1

      if compare_new_and_old_templates(conjt_str, newconjt_str, pagetitle, pagemsg, errandpagemsg):
        if headtn == "it-verb-old":
          orig_headt = str(headt)
          blib.set_template_name(headt, "it-verb")
          headt.add("1", headarg1)
          pagemsg("Replaced %s with %s" % (orig_headt, str(headt)))
        orig_conjt = str(conjt)
        del conjt.params[:]
        conjt.add("1", conjarg1)
        blib.set_template_name(conjt, "it-conj")
        pagemsg("Replaced %s with %s" % (orig_conjt, str(conjt)))
        if headtn == "it-verb-old":
          notes.append("convert {{it-verb-old}}/{{it-conj-*}} to new {{it-verb}}/{{it-conj}}")
        else:
          notes.append("convert {{it-conj-*}} to new {{it-conj}}")
      headt = None

  if not saw_headt:
    pagemsg("WARNING: Didn't see {{it-verb-old}}/{{it-verb}} head template")
    return

  return str(parsed), notes

parser = blib.create_argparser("Convert {{it-verb-old}}/{{it-verb}}/{{it-conj-*}} to {{it-verb}}/{{it-conj}}",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--ending", choices=["are", "ere", "ire", "rre"],
  help="Verb ending to process.")
parser.add_argument("--all-diffs", action="store_true",
  help="Show all differences between old and new.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.ending == "rre":
  reflexive = "[ou]rsi$"
else:
  reflexive = args.ending[:-1] + "si$"
blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:it-verb-old"],
    filter_pages=lambda title: title.endswith(args.ending) or re.search(reflexive, title))
