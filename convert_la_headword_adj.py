#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert la-adj-* to la-adj.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

import lalib

def safe_split(text, delim):
  if not text:
    return []
  return text.split(delim)

def lengthen_ns_nf(text):
  text = re.sub("an([sf])", ur"ān\1", text)
  text = re.sub("en([sf])", ur"ēn\1", text)
  text = re.sub("in([sf])", ur"īn\1", text)
  text = re.sub("on([sf])", ur"ōn\1", text)
  text = re.sub("un([sf])", ur"ūn\1", text)
  text = re.sub("yn([sf])", ur"ȳn\1", text)
  text = re.sub("An([sf])", ur"Ān\1", text)
  text = re.sub("En([sf])", ur"Ēn\1", text)
  text = re.sub("In([sf])", ur"Īn\1", text)
  text = re.sub("On([sf])", ur"Ōn\1", text)
  text = re.sub("Un([sf])", ur"Ūn\1", text)
  text = re.sub("Yn([sf])", ur"Ȳn\1", text)
  return text

def process_page(page, index, parsed):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  pagemsg("Processing")

  text = str(page.text)
  origtext = text

  notes = []

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  subsections = re.split("(^===[^=]*===\n)", secbody, 0, re.M)

  saw_a_template = False

  for k in range(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    la_adj_template = None
    la_adecl_template = None
    must_continue = False
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "la-adecl":
        if la_adecl_template:
          pagemsg("WARNING: Saw multiple adjective declension templates in subsection, %s and %s, skipping" % (
            str(la_adecl_template), str(t)))
          must_continue = True
          break
        la_adecl_template = t
        saw_a_template = True
      if tn in lalib.la_adj_headword_templates or tn in [
        "la-present participle", "la-perfect participle", "la-future participle", "la-gerundive"
      ]:
        if la_adj_template:
          pagemsg("WARNING: Saw multiple adjective headword templates in subsection, %s and %s, skipping" % (
            str(la_adj_template), str(t)))
          must_continue = True
          break
        la_adj_template = t
        saw_a_template = True
    if must_continue:
      continue
    if not la_adj_template and not la_adecl_template:
      continue
    if la_adj_template and not la_adecl_template:
      pagemsg("WARNING: Saw adjective headword template but no declension template: %s" % str(la_adj_template))
      continue
    if la_adecl_template and not la_adj_template:
      pagemsg("WARNING: Saw adjective declension template but no headword template: %s" % str(la_adecl_template))
      continue
    adj_forms = lalib.generate_adj_forms(str(la_adecl_template), errandpagemsg, expand_text)
    if adj_forms is None:
      continue
    orig_la_adj_template = str(la_adj_template)
    tn_adj = tname(la_adj_template)

    def compare_headword_decl_forms(id_slot, headword_forms, decl_slots):
      decl_forms = ""
      for slot in decl_slots:
        if slot in adj_forms:
          decl_forms = adj_forms[slot]
          break
      decl_forms = safe_split(decl_forms, ",")
      corrected_headword_forms = set(lengthen_ns_nf(x) for x in headword_forms)
      corrected_decl_forms = set(lengthen_ns_nf(x) for x in decl_forms)
      if corrected_headword_forms != corrected_decl_forms:
        macronless_headword_forms = set(lalib.remove_macrons(x) for x in corrected_headword_forms)
        macronless_decl_forms = set(lalib.remove_macrons(x) for x in corrected_decl_forms)
        if macronless_headword_forms == macronless_decl_forms:
          pagemsg("WARNING: Headword %s=%s different from decl %s=%s in macrons only, skipping" % (
            id_slot, ",".join(headword_forms), id_slot, ",".join(decl_forms)
          ))
        else:
          pagemsg("WARNING: Headword %s=%s different from decl %s=%s in more than just macrons, skipping" % (
            id_slot, ",".join(headword_forms), id_slot, ",".join(decl_forms)
          ))
        return False
      return True

    if tn_adj in ["la-adj-1&2", "la-adj-3rd-3E"]:
      nom_m = blib.fetch_param_chain(la_adj_template, ["1", "head", "head1"], "head")
      nom_f = blib.fetch_param_chain(la_adj_template, ["2", "f", "f1"], "f")
      nom_n = blib.fetch_param_chain(la_adj_template, ["3", "n", "n1"], "n")
      if not compare_headword_decl_forms("masculine", nom_m, ["nom_sg_m", "nom_pl_m"]):
        continue
      if not compare_headword_decl_forms("feminine", nom_f, ["nom_sg_f", "nom_pl_f"]):
        continue
      if not compare_headword_decl_forms("neuter", nom_n, ["nom_sg_n", "nom_pl_n"]):
        continue
    elif tn_adj == "la-adj-3rd-1E":
      nom_m = blib.fetch_param_chain(la_adj_template, ["1", "head", "head1"], "head")
      gen_m = blib.fetch_param_chain(la_adj_template, ["2", "gen", "gen1"], "gen")
      if not compare_headword_decl_forms("nominative", nom_m, ["nom_sg_m", "nom_pl_m"]):
        continue
      if not compare_headword_decl_forms("genitive", gen_m, ["gen_sg_m", "gen_pl_m"]):
        continue
    elif tn_adj == "la-adj-3rd-2E":
      nom_m = blib.fetch_param_chain(la_adj_template, ["1", "head", "head1"], "head")
      nom_n = blib.fetch_param_chain(la_adj_template, ["2", "n", "n1"], "n")
      if not compare_headword_decl_forms("masculine", nom_m, ["nom_sg_m", "nom_pl_m"]):
        continue
      if not compare_headword_decl_forms("neuter", nom_n, ["nom_sg_n", "nom_pl_n"]):
        continue
    #elif tn_adj in ["la-adj-comp", "la-adj-sup"]:
    #  nom_m = blib.fetch_param_chain(la_adj_template, ["1", "head", "head1"], "head", pagetitle)
    #  if not compare_headword_decl_forms("headword", nom_m, ["nom_sg_m", "nom_pl_m"]):
    #    continue
    #  # If 2= is specified (alias of comp=), move to comp= so it doesn't get lost.
    #  comp2 = getparam(la_adj_template, "2")
    #  compparam = "comp" if tn_adj == "la-adj-comp" else "sup"
    #  if comp2:
    #    compcomp = getparam(la_adj_template, compparam)
    #    if compcomp:
    #      pagemsg("WARNING: Saw both 2=%s and %s=%s in {{%s}}" % (
    #        comp2, compparam, compcomp, tn_adj))
    #    else:
    #      la_adj_template.add(compparam, comp2, before="2")
    #  rmparam(t, "2")
    else:
      pagemsg("Skipping {{%s}}, not among regular adjective templates" % tn_adj)
      continue

    # Fetch remaining params from headword template
    headword_params = []
    for param in la_adj_template.params:
      pname = str(param.name)
      if pname.strip() in ["1", "2", "3"] or re.search("^(head|gen|f|n)[0-9]*$", pname.strip()):
        continue
      headword_params.append((pname, param.value, param.showkey))
    # Erase all params
    del la_adj_template.params[:]
    # Copy params from decl template
    for param in la_adecl_template.params:
      pname = str(param.name)
      la_adj_template.add(pname, param.value, showkey=param.showkey, preserve_spacing=False)
    # Copy remaining params from headword template
    for name, value, showkey in headword_params:
      la_adj_template.add(name, value, showkey=showkey, preserve_spacing=False)
    blib.set_template_name(la_adj_template, "la-adj")
    pagemsg("Replaced %s with %s" % (orig_la_adj_template, str(la_adj_template)))
    notes.append("convert {{%s}} to {{la-adj}} with new params" % tn_adj)
    subsections[k] = str(parsed)

  if not saw_a_template:
    pagemsg("WARNING: Saw no adjective headword or declension templates")

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert Latin adj headword templates to new form",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Latin adjectives"], edit=True)
