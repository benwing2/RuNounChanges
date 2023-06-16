#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, errandmsg, site

import lalib

import convert_la_headword_noun

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

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn not in ["la-noun", "la-proper noun"]:
      continue

    origt = str(t)

    def render_headword():
      return "headword template <from> %s <to> %s <end>" % (origt, origt)

    if getparam(t, "indecl"):
      pagemsg("Skipping indeclinable noun: %s" % render_headword())
      continue
    new_style_headword_template = (
      not getparam(t, "head2") and
      not getparam(t, "2") and
      not getparam(t, "3") and
      not getparam(t, "4") and
      not getparam(t, "decl")
    )
    if new_style_headword_template:
      pagemsg("Skipping new-style template: %s" % render_headword())
      continue
    lemma = blib.fetch_param_chain(t, ["1", "head", "head1"], "head") or [pagetitle]
    genitive = blib.fetch_param_chain(t, ["2", "gen", "gen1"], "gen")
    noun_gender = blib.fetch_param_chain(t, ["3", "g", "g1"], "g")
    noun_decl = blib.fetch_param_chain(t, ["4", "decl", "decl1"], "decl")
    if " " in lemma[0]:
      pagemsg("WARNING: Space in lemma %s, skipping: %s" % (lemma[0], render_headword()))
      continue
    if len(lemma) > 1:
      pagemsg("WARNING: Multiple lemmas %s, skipping: %s" % (",".join(lemma), render_headword()))
      continue
    lemma = lemma[0]
    noun_decl_to_decl_type = {
      "first": "1",
      "second": "2",
      "third": "3",
      "fourth": "4",
      "fifth": "5",
      "irregular": "irreg",
    }
    if len(noun_decl) == 0:
      pagemsg("WARNING: No declension, skipping: %s" % render_headword())
      continue
    if len(noun_decl) > 1:
      pagemsg("WARNING: Multiple decls %s, skipping: %s" % (
        ",".join(noun_decl), render_headword()))
      continue
    noun_decl = noun_decl[0]
    if noun_decl not in noun_decl_to_decl_type:
      pagemsg("WARNING: Unrecognized declension %s, skipping: %s" % (
        noun_decl, render_headword()))
      continue
    decl_type = noun_decl_to_decl_type[noun_decl]
    if decl_type in ["1", "2", "4", "5"]:
      param1 = "%s<%s>" % (lemma, decl_type)
    elif decl_type == "3":
      if len(genitive) == 0:
        pagemsg("WARNING: No genitives with decl 3 lemma %s, skipping: %s" % (
          lemma, render_headword()))
        continue
      elif len(genitive) > 1:
        pagemsg("WARNING: Multiple genitives %s with decl 3 lemma %s, skipping: %s" % (
          ",".join(genitive), lemma, render_headword()))
        continue
      else:
        gen1 = genitive[0]
        if gen1.endswith("is"):
          stem = gen1[:-2]
          if lalib.infer_3rd_decl_stem(lemma) == stem:
            param1 = "%s<3>" % lemma
          else:
            param1 = "%s/%s<3>" % (lemma, stem)
        elif gen1.endswith("ium"):
          if lemma.endswith("ia"):
            param1 = "%s<3.pl>" % lemma
          elif lemma.endswith(u"ēs"):
            param1 = "%s<3.I.pl>" % lemma
          else:
            pagemsg("WARNING: Unrecognized lemma %s with decl 3 genitive -ium, skipping: %s" % (
              lemma, render_headword()))
            continue
        elif gen1.endswith("um"):
          if lemma.endswith("a") or lemma.endswith(u"ēs"):
            param1 = "%s<3.pl>" % lemma
          else:
            pagemsg("WARNING: Unrecognized lemma %s with decl 3 genitive -um, skipping: %s" % (
              lemma, render_headword()))
            continue
        else:
          pagemsg("WARNING: Unrecognized genitive %s with decl 3 lemma %s, skipping: %s" % (
            gen1, lemma, render_headword()))
          continue
    elif decl_type == "irreg":
      pagemsg("WARNING: Can't handle irregular nouns, skipping: %s" % render_headword())
      continue
    else:
      pagemsg("WARNING: Something wrong, unrecognized decl_type %s, skipping: %s" % (
        decl_type, render_headword()))
      continue
    la_ndecl = "{{la-ndecl|%s}}" % param1
    noun_props = convert_la_headword_noun.new_generate_noun_forms(la_ndecl,
        errandpagemsg, expand_text, include_props=True)
    if noun_props is None:
      continue
    decl_gender = noun_props.get("g", None)
    if not convert_la_headword_noun.compare_headword_decl_forms("genitive",
      genitive, ["gen_sg", "gen_pl"], noun_props,
      render_headword(), pagemsg, adjust_for_missing_gen_forms=True,
      adjust_for_e_ae_gen=True, remove_headword_links=True):
      continue
    if len(noun_gender) == 1 and noun_gender[0] == decl_gender:
      need_explicit_gender = False
    else:
      need_explicit_gender = True
      if len(noun_gender) > 1:
        pagemsg("WARNING: Saw multiple headword genders %s, please verify: %s" % (
          ",".join(noun_gender), render_headword()))
      elif (noun_gender and noun_gender[0].startswith("n") != (decl_gender == "n")):
        pagemsg("WARNING: Headword gender %s is neuter and decl gender %s isn't, or vice-versa, need to correct, skipping: %s" % (
        noun_gender[0], decl_gender, render_headword()))
        continue

    # Fetch remaining params from headword template
    headword_params = []
    for param in t.params:
      pname = str(param.name)
      if pname.strip() in ["1", "2", "3", "4"] or re.search("^(head|gen|g|decl)[0-9]*$", pname.strip()):
        continue
      headword_params.append((pname, param.value, param.showkey))
    # Erase all params
    del t.params[:]
    # Add param1
    t.add("1", param1)
    # Add explicit gender if needed
    if need_explicit_gender:
      explicit_genders = []
      for ng in noun_gender:
        ng = ng[0]
        if ng not in explicit_genders:
          explicit_genders.append(ng)
      blib.set_param_chain(t, explicit_genders, "g", "g")
    # Copy remaining params from headword template
    for name, value, showkey in headword_params:
      t.add(name, value, showkey=showkey, preserve_spacing=False)
    pagemsg("Replaced %s with %s" % (origt, str(t)))
    notes.append("convert {{la-noun}}/{{la-proper noun}} params to new style")

  return str(parsed), notes

parser = blib.create_argparser("Convert headword template to new style params without decl",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Latin reconstructed nouns", "Latin reconstructed proper nouns"], edit=True)
