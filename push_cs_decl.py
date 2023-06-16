#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, argparse, codecs, json
import traceback, sys
import pywikibot
import blib
from blib import rmparam, getparam, msg, errandmsg, site, tname

cs_decl_noun_slots = [
  "nom_s", "gen_s", "dat_s", "acc_s", "voc_s", "loc_s", "ins_s",
  "nom_p", "gen_p", "dat_p", "acc_p", "voc_p", "loc_p", "ins_p",
]
cs_decl_noun_sg_slots = [
  "nom_s", "gen_s", "dat_s", "acc_s", "voc_s", "loc_s", "ins_s",
]
cs_decl_noun_pl_slots = [
  "nom_p", "gen_p", "dat_p", "acc_p", "voc_p", "loc_p", "ins_p",
]

def compare_form(slot, orig, repl, pagemsg):
  origforms = orig.split(",")
  replforms = repl.split(",")
  return set(origforms) == set(replforms)

def compare_forms(origforms, replforms, ignore_slots, pagemsg):
  displaycall = tempcall.replace("|json=1", "")
  for slot in set(replforms.keys() + origforms.keys()):
    if slot.endswith("_linked"):
      continue
    if slot in ignore_slots:
      origform = origforms.get(slot, "missing")
      replform = replforms.get(slot, "missing")
      pagemsg("Skipping slot %s in ignore_slots (original=%s, replacement=%s)" % (slot, origform, replform))
      continue
    if slot not in origforms:
      pagemsg("WARNING: for replacement %s, form %s=%s in replacement forms but missing in original forms" % (
        displaycall, slot, replforms[slot]))
      return False
    if slot not in replforms:
      pagemsg("WARNING: for predicted %s, form %s=%s in original forms but missing in replacement forms" % (
        displaycall, slot, origforms[slot]))
      return False
    origform = origforms[slot]
    if not compare_form(slot, origform, replforms[slot], pagemsg):
      pagemsg("WARNING: for predicted %s, form %s=%s in replacement forms but =%s in original forms" % (
        displaycall, slot, replforms[slot], origform))
      return False
  return True

def replace_decl(page, index, parsed, decl, declforms, ignore_slots):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  pagemsg("Processing decl {{cs-ndecl|%s}}" % decl)
  notes = []
  saw_decl = False
  for t in parsed.filter_templates():
    tn = tname(t)
    forms = {}

    if tn == "cs-decl-noun":
      number = ""
      getslots = cs_decl_noun_slots
      saw_decl = True
    elif tn == "cs-decl-noun-sg":
      number = "sg"
      getslots = cs_decl_noun_sg_slots
      saw_decl = True
    elif tn == "cs-decl-noun-pl":
      number = "pl"
      getslots = cs_decl_noun_pl_slots
      saw_decl = True
    else:
      if tn == "cs-ndecl":
        saw_decl = True
      continue

    i = 1
    for slot in getslots:
      if slot:
        pref = re.sub("^(.).*(.)$", r"\1\2", slot)
        vals = blib.fetch_param_chain(t, str(i), pref)
        vals = [blib.remove_links(v).strip() for v in vals]
        if not vals:
          continue
        form = ",".join(vals)
        # eliminate spaces around commas
        form = re.sub(r"\s*[,/]\s*", ",", form)
        forms[slot] = form
      i += 1

    if compare_forms(forms, declforms, ignore_slots, pagemsg):
      origt = str(t)
      t.name = "cs-ndecl"
      del t.params[:]
      t.add("1", decl)
      newt = str(t)
      ignore_msg = ""
      if ignore_slots:
        ignore_msg = " (ignoring slot%s %s, likely wrong)" % (
          "s" if len(ignore_slots) > 1 else "", ",".join(ignore_slots)
        )
      pagemsg("Replaced %s with %s%s" % (origt, newt, ignore_msg))
      notes.append("replace {{%s|...}} with %s%s" % (tn, newt, ignore_msg))

  if not saw_decl:
    pagemsg("WARNING: Didn't see declension")

  return str(parsed), notes

parser = blib.create_argparser("Replace manual declensions with given automatic ones")
parser.add_argument("--declfile", help="File containing replacement declensions", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def yield_decls():
  for lineno, line in blib.iter_items_from_file(args.declfile, start, end):
    m = re.search(r'^\[\[(.*?)\]\] ".*?" (.*)$', line)
    if not m:
      m = re.search(r"^\[\[(.*?)\]\] (.*)$", line)
    if not m:
      msg("Line %s: WARNING: Unrecognized line: %s" % (lineno, line))
      continue
    pagename, decl = m.groups()
    m = re.search("^(.*) !([^ ]*)$", decl)
    if m:
      decl, ignore_slots = m.groups()
      ignore_slots = ignore_slots.split(",")
    else:
      ignore_slots = []
    yield lineno, pagename, decl, ignore_slots

for index, pagename, decl, ignore_slots in yield_decls():
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagename, pagemsg, args.verbose)
  tempcall = "{{cs-ndecl|%s|json=1}}" % decl
  result = expand_text(tempcall)
  if not result:
    continue
  result = json.loads(result)
  def flatten_values(values):
    retval = []
    for v in values:
      retval.append(v["form"])
    return ",".join(retval)
  predforms = {
    k: blib.remove_links(flatten_values(v)) for k, v in result["forms"].iteritems()
  }
  lemma = predforms["nom_s"] if "nom_s" in predforms else predforms["nom_p"]
  real_pagename = re.sub(",.*", "", blib.remove_links(lemma))
  page = pywikibot.Page(site, real_pagename)
  if not blib.safe_page_exists(page, errandpagemsg):
    pagemsg("WARNING: Didn't find page; declension is {{cs-ndecl|%s}}" % decl)
    continue
  def do_replace_decl(page, index, parsed):
    return replace_decl(page, index, parsed, decl, predforms, ignore_slots)
  blib.do_edit(page, index, do_replace_decl, save=args.save, verbose=args.verbose,
      diff=args.diff)
