#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, argparse
import traceback, sys
import pywikibot
import blib
from blib import rmparam, getparam, msg, site, tname

import belib as be

be_conj_slots = [
  "infinitive",
  "past_pasv_part",
  "pres_adv_part",
  "past_adv_part",
  "pres_futr_1sg",
  "pres_futr_2sg",
  "pres_futr_3sg",
  "pres_futr_1pl",
  "pres_futr_2pl",
  "pres_futr_3pl",
  "impr_sg",
  "impr_pl",
  "past_m",
  "past_f",
  "past_n",
  "past_pl",
]

def compare_form(slot, orig, repl, pagemsg):
  origforms = [be.remove_monosyllabic_accents(x) for x in re.split(", *", orig)]
  replforms = [be.remove_monosyllabic_accents(x) for x in re.split(", *", repl)]
  return set(origforms) == set(replforms)

def compare_forms(autoconj, origforms, replforms, pagemsg):
  for slot in set(replforms.keys() + origforms.keys()):
    if slot in replforms and "[[" in replforms[slot]:
      continue
    if slot == "past_adv_part" and slot in replforms and slot not in origforms:
      pagemsg("Past adverbial part %s in new but not old forms, allowing" % replforms[slot])
      continue
    if slot not in origforms:
      pagemsg("WARNING: for replacement %s, form %s=%s in replacement forms but missing in original forms" % (
        autoconj, slot, replforms[slot]))
      return False
    if slot not in replforms:
      pagemsg("WARNING: for predicted %s, form %s=%s in original forms but missing in replacement forms" % (
        autoconj, slot, origforms[slot]))
      return False
    if not compare_form(slot, origforms[slot], replforms[slot], pagemsg):
      pagemsg("WARNING: for predicted %s, form %s=%s in replacement forms but =%s in original forms" % (
        autoconj, slot, replforms[slot], origforms[slot]))
      return False
  return True

def process_section(index, pagetitle, sectext):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
  pagemsg("Processing")
  notes = []
  conjt = None
  parsed = blib.parse_text(sectext)
  for t in parsed.filter_templates():
    tn = tname(t)
    forms = {}

    if tn == "be-conj-manual":
      if conjt:
        pagemsg("WARNING: Saw two conjugation templates %s and %s, skipping" %
          (str(conjt), str(t)))
        return sectext, notes
      conjt = t
  if not conjt:
    pagemsg("WARNING: Couldn't find conjugation template")
    return sectext, notes
  autoconj = None
  for m in re.finditer("<!-- type (.*?) -->", sectext):
    if autoconj:
      pagemsg("WARNING: Saw two autoconj comments %s and %s, skipping" % (
        autoconj, m.group(1)))
      return sectext, notes
    autoconj = m.group(1)
    autoconj = re.sub(" PPP[=:].*", "", autoconj)
    if " " in autoconj:
      pagemsg("WARNING: Space in autoconj, skipping: %s" % autoconj)
      return sectext, notes
  if not autoconj:
    pagemsg("WARNING: Couldn't find autoconj comment")
    return sectext, notes
  if not autoconj.startswith("(("):
    infinitive = getparam(conjt, "infinitive").strip()
    if not infinitive:
      pagemsg("WARNING: Couldn't find infinitive=: %s" % str(conjt))
      return sectext, notes
    autoconj = "%s<%s>" % (infinitive, autoconj)
  tempcall = "{{User:Benwing2/be-generate-verb-forms|%s}}" % autoconj
  result = expand_text(tempcall)
  if not result:
    return sectext, notes
  pagemsg(result)
  predforms = blib.split_generate_args(result)
  forms = {}
  aspect = getparam(conjt, "aspect").strip()
  for slot in be_conj_slots:
    form = getparam(conjt, slot).strip()
    if form and form != "-":
      if slot.startswith("pres_futr_"):
        if aspect == "pf":
          forms[slot.replace("pres_", "")] = form
        else:
          forms[slot.replace("futr_", "")] = form
      else:
        forms[slot] = form
  if compare_forms(autoconj, forms, predforms, pagemsg):
    origt = str(conjt)
    conjt.name = "be-conj"
    del conjt.params[:]
    conjt.add("1", autoconj)
    newt = str(conjt)
    pagemsg("Replaced %s with %s" % (origt, newt))
    notes.append("replace {{be-conj-manual|...}} with %s" % newt)
  sectext = str(parsed)
  if notes:
    sectext = re.sub("<!-- type (.*?) -->", "", sectext)

  return sectext, notes

def process_page(page, index, parsed):
  notes = []
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  text = str(page.text)
  retval = blib.find_modifiable_lang_section(text, "Belarusian", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Belarusian section")
    return
  sections, j, secbody, sectail, has_non_lang = retval
  if "Etymology 1" in secbody:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    for k in range(2, len(etym_sections), 2):
      etym_sections[k], this_notes = process_section(index, pagetitle, etym_sections[k])
      notes.extend(this_notes)
    secbody = "".join(etym_sections)
  else:
    secbody, this_notes = process_section(index, pagetitle, secbody)
    notes.extend(this_notes)
  sections[j] = secbody + sectail
  if notes:
    sections[j] = re.sub(r"\{\{cln\|be\|(in)?transitive verbs\}\}\n?", "", sections[j])
  return "".join(sections), notes

parser = blib.create_argparser("Replace Belarusian manual conjugations with automatic ones",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_refs=["Template:be-conj-manual"], edit=True)
