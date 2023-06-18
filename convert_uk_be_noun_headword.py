#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import uklib as uk
import belib as be

AC = u"\u0301"

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []
  pagemsg("Processing")

  heads = None
  headt = None
  headtn = None
  gender_and_animacy = None
  genitives = None
  plurals = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in [args.lang + "-noun", args.lang + "-proper noun"]:
      if heads:
        pagemsg("WARNING: Encountered headword twice without declension: %s" % str(t))
        return
      headt = t
      headtn = tn
      heads = blib.fetch_param_chain(t, "1", "head")
      gender_and_animacy = blib.fetch_param_chain(t, "2", "g")
      genitives = blib.fetch_param_chain(t, "3", "gen")
      plurals = blib.fetch_param_chain(t, "4", "pl")
      genitive_plurals = blib.fetch_param_chain(t, "5", "genpl")
    if tn == args.lang + "-ndecl":
      if not heads:
        pagemsg("WARNING: Encountered decl without headword: %s" % str(t))
        return
      generate_template = re.sub(r"^\{\{%s-ndecl\|" % args.lang, "{{User:Benwing2/%s-generate-prod-noun-props|" % args.lang,
          str(t))
      result = expand_text(generate_template)
      if not result:
        return
      new_forms = blib.split_generate_args(result)
      new_g = new_forms["g"].split(",")
      def compare(old, new, stuff, nocanon=False):
        if not old:
          return True
        if not nocanon:
          remove_monosyllabic_accents = (
            uk.remove_monosyllabic_stress if args.lang == "uk" else
            be.remove_monosyllabic_accents
          )
          old = [remove_monosyllabic_accents(blib.remove_links(x)) for x in old]
          new = [remove_monosyllabic_accents(x) for x in new]
        if set(old) != set(new):
          pagemsg("WARNING: Old %ss %s disagree with new %ss %s: head=%s, decl=%s" % (
            stuff, ",".join(old), stuff, ",".join(new), str(headt), str(t)))
          return False
        return True
      if not compare(gender_and_animacy, new_g, "gender", nocanon=True):
        heads = None
        continue
      is_plural = [x.endswith("-p") for x in new_g]
      if any(is_plural) and not all(is_plural):
        pagemsg("WARNING: Mixture of plural-only and non-plural-only genders, can't process: %s" %
            str(t))
        return
      is_plural = any(is_plural)
      if is_plural:
        if (not compare(heads, new_forms.get("nom_p", "-").split(","), "nom pl") or
            not compare(genitives, new_forms.get("gen_p", "-").split(","), "gen pl")):
          heads = None
          continue
      else:
        if (not compare(heads, new_forms.get("nom_s", "-").split(","), "nom sg") or
            not compare(genitives, new_forms.get("gen_s", "-").split(","), "gen sg") or
            # 'uk/be-proper noun' headwords don't have nominative plural set
            headtn == args.lang + "-noun" and not compare(plurals, new_forms.get("nom_p", "-").split(","), "nom pl") or
            headtn == args.lang + "-noun" and not compare(genitive_plurals, new_forms.get("gen_p", "-").split(","), "gen pl")):
          heads = None
          continue
      decl = getparam(t, "1")
      blib.set_param_chain(headt, [decl], "1", "head")
      blib.remove_param_chain(headt, "2", "g")
      blib.remove_param_chain(headt, "3", "gen")
      blib.remove_param_chain(headt, "4", "pl")
      blib.remove_param_chain(headt, "5", "genpl")
      notes.append("convert {{%s}} to new style using decl %s" % (str(headt.name), decl))
      heads = None
  return str(parsed), notes

parser = blib.create_argparser("Convert {{uk-noun}}/{{be-noun}} to new style", include_pagefile=True)
parser.add_argument("--lang", required=True, help="Language (uk or be)")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.lang not in ["uk", "be"]:
  raise ValueError("Unrecognized language: %s" % args.lang)
langname = "Ukrainian" if args.lang == "uk" else "Belarusian"

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=[langname + " nouns", langname + " proper nouns"], edit=True)
