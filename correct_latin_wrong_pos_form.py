#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

def process_form(page, index, slot, form, pos, pagemsg):
  orig_pagemsg = pagemsg
  def pagemsg(txt):
    orig_pagemsg("%s %s %s: %s" % (index, slot, form, txt))

  notes = []

  pagemsg("Processing")

  if not page.exists():
    pagemsg("Skipping form value %s, page doesn't exist" % form)
    return None, None

  text = str(page.text)

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  if pos == "pn":
    from_header = "==Noun=="
    to_header = "==Proper noun=="
    from_headword_template = "la-noun-form"
    to_headword_template = "la-proper noun-form"
    from_pos = "noun form"
    to_pos = "proper noun form"
    from_lemma_pos = "noun"
    to_lemma_pos = "proper noun"
  elif pos == "part":
    from_header = "==Adjective=="
    to_header = "==Participle=="
    from_headword_template = "la-adj-form"
    to_headword_template = "la-part-form"
    from_pos = "adjective form"
    to_pos = "participle form"
    from_lemma_pos = "adjective"
    to_lemma_pos = "participle"
  else:
    raise ValueError("Unrecognized POS %s" % pos)

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  for k in range(2, len(subsections), 2):
    if (re.search(r"\{\{%s([|}])" % from_headword_template, subsections[k]) or
        re.search(r"\{\{head\|la\|%s([|}])" % from_pos, subsections[k])):
      newsubsec = subsections[k]
      newsubsec = re.sub(r"\{\{%s([|}])" % from_headword_template, r"{{%s\1" % to_headword_template, newsubsec)
      newsubsec = re.sub(r"\{\{head\|la\|%s([|}])" % from_pos, r"{{head|la|%s\1" % to_pos, newsubsec)
      newheadersubsec = subsections[k - 1]
      newheadersubsec = newheadersubsec.replace(from_header, to_header)
      if newsubsec != subsections[k] or newheadersubsec != subsections[k - 1]:
        notes.append("non-lemma %s -> %s in header and headword" % (
          from_lemma_pos, to_lemma_pos))
      subsections[k] = newsubsec
      subsections[k - 1] = newheadersubsec

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  text = "".join(sections)
  return text, notes

def process_page(page, index):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  text = str(page.text)

  retval = lalib.find_heads_and_defns(text, pagemsg)
  if retval is None:
    return None, None

  (
    sections, j, secbody, sectail, has_non_latin, subsections,
    parsed_subsections, headwords, pronun_sections, etym_sections
  ) = retval

  part_headwords = []
  adj_headwords = []
  pn_headwords = []
  noun_headwords = []

  for headword in headwords:
    ht = headword['head_template']
    tn = tname(ht)
    if tn == "la-part" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") in ["participle", "participles"]:
      part_headwords.append(headword)
    elif tn == "la-adj" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") in ["adjective", "adjectives"]:
      adj_headwords.append(headword)
    elif tn == "la-proper noun" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") in ["proper noun", "proper nouns"]:
      pn_headwords.append(headword)
    elif tn == "la-noun" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") in ["noun", "nouns"]:
      noun_headwords.append(headword)
  headwords_to_do = None
  if part_headwords and not adj_headwords:
    pos = "part"
    headwords_to_do = part_headwords
    expected_inflt = "la-adecl"
  elif pn_headwords and not noun_headwords:
    pos = "pn"
    headwords_to_do = pn_headwords
    expected_inflt = "la-ndecl"

  if not headwords_to_do:
    return None, None

  for headword in headwords_to_do:
    for inflt in headword['infl_templates']:
      infltn = tname(inflt)
      if infltn != expected_inflt:
        pagemsg("WARNING: Saw bad declension template for %s, expected {{%s}}: %s" % (
          pos, expected_inflt, str(inflt)))
        continue
      inflargs = lalib.generate_infl_forms(pos, str(inflt), errandpagemsg, expand_text)
      forms_seen = set()
      slots_and_forms_to_process = []
      for slot, formarg in inflargs.iteritems():
        forms = formarg.split(",")
        for form in forms:
          if "[" in form or "|" in form:
            continue
          form_no_macrons = lalib.remove_macrons(form)
          if form_no_macrons == pagetitle:
            continue
          if form_no_macrons in forms_seen:
            continue
          forms_seen.add(form_no_macrons)
          slots_and_forms_to_process.append((slot, form))
      for formindex, (slot, form) in blib.iter_items(sorted(slots_and_forms_to_process,
          key=lambda x: lalib.remove_macrons(x[1]))):
        def handler(page, formindex, parsed):
          return process_form(page, formindex, slot, form, pos, pagemsg)
        blib.do_edit(pywikibot.Page(site, lalib.remove_macrons(form)),
            "%s.%s" % (index, formindex),
            handler, save=args.save, verbose=args.verbose, diff=args.diff)

parser = blib.create_argparser(u"Correct headers/headwords of non-lemma forms with the wrong part of speech",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Latin participles", "Latin proper nouns"])
