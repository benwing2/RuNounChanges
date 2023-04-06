#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, argparse, codecs, json
import traceback, sys
import pywikibot
import blib
from blib import rmparam, getparam, msg, site, tname

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

def compare_forms(origforms, replforms, pagemsg):
  for slot in set(replforms.keys() + origforms.keys()):
    if slot.endswith("_linked"):
      continue
    if slot not in origforms:
      pagemsg("WARNING: for replacement %s, form %s=%s in replacement forms but missing in original forms" % (
        tempcall, slot, replforms[slot]))
      return False
    if slot not in replforms:
      pagemsg("WARNING: for predicted %s, form %s=%s in original forms but missing in replacement forms" % (
        tempcall, slot, origforms[slot]))
      return False
    origform = origforms[slot]
    if not compare_form(slot, origform, replforms[slot], pagemsg):
      pagemsg("WARNING: for predicted %s, form %s=%s in replacement forms but =%s in original forms" % (
        tempcall, slot, replforms[slot], origform))
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

    if tn == "cs-decl-noun":
      number = ""
      getslots = cs_decl_noun_slots
    elif tn == "cs-decl-noun-sg":
      number = "sg"
      getslots = cs_decl_noun_sg_slots
    elif tn == "cs-decl-noun-pl":
      number = "pl"
      getslots = cs_decl_noun_pl_slots
    else:
      continue

    i = 1
    for slot in getslots:
      if slot:
        form = getparam(t, i).strip()
        if not form:
          continue
        form = blib.remove_links(form)
        # eliminate spaces around commas
        form = re.sub(r"\s*[,/]\s*", ",", form)
        forms[slot] = form
      i += 1

    if compare_forms(forms, declforms, pagemsg):
      origt = unicode(t)
      t.name = "cs-ndecl"
      del t.params[:]
      t.add("1", decl)
      newt = unicode(t)
      pagemsg("Replaced %s with %s" % (origt, newt))
      notes.append("replace {{%s|...}} with %s" % (tn, newt))

  return unicode(parsed), notes

parser = blib.create_argparser("Replace manual declensions with given automatic ones")
parser.add_argument("--declfile", help="File containing replacement declensions", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def yield_decls():
  for lineno, line in blib.iter_items_from_file(args.declfile, start, end):
    m = re.search(r'^\[\[(.*?)\]\] ".*?" (.*)$', line)
    if not m:
      m = re.search(r'^\[\[(.*?)\]\] (.*)$', line)
    if not m:
      msg("Line %s: WARNING: Unrecognized line: %s" % (lineno, line))
      continue
    pagename, decl = m.groups()
    yield lineno, pagename, decl

for index, pagename, decl in yield_decls():
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
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
  def do_replace_decl(page, index, parsed):
    return replace_decl(page, index, parsed, decl, predforms)
  blib.do_edit(page, index, do_replace_decl, save=args.save, verbose=args.verbose,
      diff=args.diff)
