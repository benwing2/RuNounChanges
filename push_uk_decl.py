#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, argparse, codecs
import traceback, sys
import pywikibot
import blib
from blib import rmparam, getparam, msg, site, tname

import uklib as uk

uk_decl_noun_slots = [
  "nom_s", "nom_p", "gen_s", "gen_p", "dat_s", "dat_p",
  "acc_s", "acc_p", "ins_s", "ins_p", "loc_s", "loc_p",
  "voc_s", "voc_p"]
uk_decl_noun_unc_slots = [
  "nom_s", "gen_s", "dat_s", "acc_s", "ins_s", "loc_s", "voc_s"
]
uk_decl_noun_pl_slots = [
  "nom_p", "gen_p", "dat_p", "acc_p", "ins_p", "loc_p", "voc_p"
]

def compare_form(slot, orig, repl, pagemsg):
  origforms = orig.split(",")
  replforms = repl.split(",")
  return set(origforms) == set(replforms)

def compare_forms(origforms, replforms, pagemsg):
  for slot in set(replforms.keys() + origforms.keys()):
    if slot not in origforms:
      pagemsg("WARNING: for replacement %s, form %s=%s in replacement forms but missing in original forms" % (
        tempcall, slot, replforms[slot]))
      return False
    if slot not in replforms:
      pagemsg("WARNING: for predicted %s, form %s=%s in original forms but missing in replacement forms" % (
        tempcall, slot, origforms[slot]))
      return False
    if not compare_form(slot, origforms[slot], replforms[slot], pagemsg):
      pagemsg("WARNING: for predicted %s, form %s=%s in replacement forms but =%s in original forms" % (
        tempcall, slot, replforms[slot], origforms[slot]))
      return False
  return True

def replace_decl(page, index, parsed, decl, declforms):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  pagemsg("Processing decl %s" % decl)
  notes = []
  for t in parsed.filter_templates():
    tn = tname(t)
    forms = {}

    if tn == "uk-decl-noun":
      number = ""
      getslots = uk_decl_noun_slots
    elif tn == "uk-decl-noun-unc":
      number = "sg"
      getslots = uk_decl_noun_unc_slots
    elif tn == "uk-decl-noun-pl":
      number = "pl"
      getslots = uk_decl_noun_pl_slots
    else:
      continue

    i = 1
    for slot in getslots:
      if slot:
        form = getparam(t, i).strip()
        form = blib.remove_links(form)
        # eliminate spaces around commas
        form = re.sub(r"\s*,\s*", ",", form)
        slotforms = form.split(",")
        slotforms = [uk.add_monosyllabic_stress(f) for f in slotforms]
        forms[slot] = ",".join(slotforms)
      i += 1

    if compare_forms(forms, declforms, pagemsg):
      origt = unicode(t)
      t.name = "uk-ndecl"
      del t.params[:]
      t.add("1", decl)
      newt = unicode(t)
      pagemsg("Replaced %s with %s" % (origt, newt))
      notes.append("replace {{%s|...}} with %s" % (tn, newt))

  return unicode(parsed), notes

parser = blib.create_argparser("Replace manual declensions with given automatic ones")
parser.add_argument("--declfile", help="File containing replacement declensions")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = [x.strip() for x in codecs.open(args.declfile, "r", "utf-8")]

def yield_decls():
  for line in lines:
    for m in re.finditer(r"\(\(.*?\)\)|[^| \[\]]+<.*?\>", line):
      yield m.group(0)

for index, decl in blib.iter_items(yield_decls(), start, end):
  if decl.startswith("(("):
    m = re.search(r"^\(\((.*)\)\)$", decl)
    subdecls = m.group(1).split(",")
    decl_for_page = subdecls[0]
  else:
    decl_for_page = decl
  m = re.search(r"^(.+?)<.*>$", decl_for_page)
  if not m:
    msg("WARNING: Can't extract lemma from decl: %s" % decl)
    pagename = "UNKNOWN"
  else:
    pagename = uk.remove_accents(blib.remove_links(m.group(1)))
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagename, pagemsg, args.verbose)
  tempcall = "{{uk-generate-noun-forms|%s}}" % decl
  result = expand_text(tempcall)
  if not result:
    continue
  predforms = blib.split_generate_args(result)
  lemma = predforms["nom_s"] if "nom_s" in predforms else predforms["nom_p"]
  real_pagename = re.sub(",.*", "", uk.remove_accents(blib.remove_links(lemma)))
  page = pywikibot.Page(site, real_pagename)
  def do_replace_decl(page, index, parsed):
    return replace_decl(page, index, parsed, decl, predforms)
  blib.do_edit(page, index, do_replace_decl, save=args.save, verbose=args.verbose,
      diff=args.diff)
