#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, errandmsg, site

import lalib

import convert_la_headword_noun

def process_line(index, line, online):
  global args
  line = line.strip()
  m = re.search(r"^Page [0-9]+ (.*?): WARNING: Saw noun headword template.*: (\{\{la-(?:proper )?noun\|.*?\}\})$", line)
  if not m:
    msg("Unrecognized line, skipping: %s" % line)
    return
  pagetitle, noun_headword_template = m.groups()
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  t = blib.parse_text(noun_headword_template).filter_templates()[0]
  if getparam(t, "indecl"):
    pagemsg("Skipping indeclinable noun: %s" % str(t))
    return
  lemma = blib.fetch_param_chain(t, ["1", "head", "head1"], "head") or [pagetitle]
  genitive = blib.fetch_param_chain(t, ["2", "gen", "gen1"], "gen")
  noun_gender = blib.fetch_param_chain(t, ["3", "g", "g1"], "g")
  noun_decl = blib.fetch_param_chain(t, ["4", "decl", "decl1"], "decl")
  if " " in lemma[0]:
    pagemsg("WARNING: Space in lemma %s, skipping: %s" % (lemma[0], str(t)))
    return
  if len(lemma) > 1:
    pagemsg("WARNING: Multiple lemmas %s, skipping: %s" % (",".join(lemma), str(t)))
    return
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
    pagemsg("WARNING: No declension, skipping: %s" % str(t))
    return
  if len(noun_decl) > 1:
    pagemsg("WARNING: Multiple decls %s, skipping: %s" % (
      ",".join(noun_decl), str(t)))
    return
  noun_decl = noun_decl[0]
  if noun_decl not in noun_decl_to_decl_type:
    pagemsg("WARNING: Unrecognized declension %s, skipping: %s" % (
      noun_decl, str(t)))
    return
  decl_type = noun_decl_to_decl_type[noun_decl]
  if decl_type in ["1", "2", "4", "5"]:
    la_ndecl = "{{la-ndecl|%s<%s>}}" % (lemma, decl_type)
  elif decl_type == "3":
    if len(genitive) == 0:
      pagemsg("WARNING: No genitives with decl 3 lemma %s, skipping: %s" % (
        lemma, str(t)))
      return
    elif len(genitive) > 1:
      pagemsg("WARNING: Multiple genitives %s with decl 3 lemma %s, skipping: %s" % (
        ",".join(genitive), lemma, str(t)))
      return
    else:
      gen1 = genitive[0]
      if gen1.endswith("is"):
        stem = gen1[:-2]
        if lalib.infer_3rd_decl_stem(lemma) == stem:
          la_ndecl = "{{la-ndecl|%s<3>}}" % lemma
        else:
          la_ndecl = "{{la-ndecl|%s/%s<3>}}" % (lemma, stem)
      elif gen1.endswith("ium"):
        if lemma.endswith("ia"):
          la_ndecl = "{{la-ndecl|%s<3.pl>}}" % lemma
        elif lemma.endswith(u"ēs"):
          la_ndecl = "{{la-ndecl|%s<3.I.pl>}}" % lemma
        else:
          pagemsg("WARNING: Unrecognized lemma %s with decl 3 genitive -ium, skipping: %s" % (
            lemma, str(t)))
          return
      elif gen1.endswith("um"):
        if lemma.endswith("a") or lemma.endswith(u"ēs"):
          la_ndecl = "{{la-ndecl|%s<3.pl>}}" % lemma
        else:
          pagemsg("WARNING: Unrecognized lemma %s with decl 3 genitive -um, skipping: %s" % (
            lemma, str(t)))
          return
      else:
        pagemsg("WARNING: Unrecognized genitive %s with decl 3 lemma %s, skipping: %s" % (
          gen1, lemma, str(t)))
        return
  elif decl_type == "irreg":
    pagemsg("WARNING: Can't handle irregular nouns, skipping: %s" % str(t))
    return
  else:
    pagemsg("WARNING: Something wrong, unrecognized decl_type %s, skipping: %s" % (
      decl_type, str(t)))
    return
  pagemsg("For noun %s, declension %s" % (str(t), la_ndecl))
  if online:
    noun_props = convert_la_headword_noun.new_generate_noun_forms(la_ndecl, errandpagemsg,
      expand_text)
    if noun_props is None:
      return
    convert_la_headword_noun.compare_headword_decl_forms("genitive", genitive,
        ["gen_sg", "gen_pl"], noun_props,
        "headword=%s, decl=%s" % (str(t), la_ndecl), pagemsg,
        adjust_for_missing_gen_forms=True, remove_headword_links=True)

parser = blib.create_argparser("Add missing declension to Latin terms")
parser.add_argument("--direcfile", help="List of directives to process.", required=True)
parser.add_argument("--online", help="Compare generated declension against specified principal parts", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, line in blib.iter_items_from_file(args.direcfile, start, end):
  process_line(i, line, args.online)
