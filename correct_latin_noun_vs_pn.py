#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

pages_to_delete = []

def process_form(page, index, slot, form, pos):
  def pagemsg(txt):
    msg("Page %s %s %s: %s" % (index, slot, form, txt))

  notes = []

  pagemsg("Processing")

  if not page.exists():
    pagemsg("Skipping form value %s, page doesn't exist" % form)
    return None, None

  text = unicode(page.text)

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
  elif pos == "n":
    from_header = "==Proper noun=="
    to_header = "==Noun=="
    from_headword_template = "la-proper noun-form"
    to_headword_template = "la-noun-form"
    from_pos = "proper noun form"
    to_pos = "noun form"
    from_lemma_pos = "proper noun"
    to_lemma_pos = "noun"
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
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  text = unicode(page.text)

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return

  sections, j, secbody, sectail, has_non_latin = retval

  parsed = blib.parse_text(secbody)
  saw_noun = None
  saw_proper_noun = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "la-noun":
      if saw_noun:
        pagemsg("WARNING: Saw multiple nouns %s and %s, not sure how to proceed, skipping" % (
          unicode(saw_noun), unicode(t)))
        return
      saw_noun = t
    elif tn == "la-proper noun":
      if saw_proper_noun:
        pagemsg("WARNING: Saw multiple proper nouns %s and %s, not sure how to proceed, skipping" % (
          unicode(saw_proper_noun), unicode(t)))
        return
      saw_proper_noun = t
  if saw_noun and saw_proper_noun:
    pagemsg("WARNING: Saw both noun and proper noun, can't correct header/headword")
    return
  if not saw_noun and not saw_proper_noun:
    pagemsg("WARNING: Saw neither noun nor proper noun, can't correct header/headword")
    return
  pos = "pn" if saw_proper_noun else "n"
  ht = saw_proper_noun or saw_noun
  if getparam(ht, "indecl"):
    pagemsg("Noun is indeclinable, skipping: %s" % unicode(ht))
    return
  generate_template = blib.parse_text(unicode(ht)).filter_templates()[0]
  blib.set_template_name(generate_template, "la-generate-noun-forms")
  blib.remove_param_chain(generate_template, "lemma", "lemma")
  blib.remove_param_chain(generate_template, "m", "m")
  blib.remove_param_chain(generate_template, "f", "f")
  blib.remove_param_chain(generate_template, "g", "g")
  rmparam(generate_template, "type")
  rmparam(generate_template, "indecl")
  rmparam(generate_template, "id")
  rmparam(generate_template, "pos")
  result = expand_text(unicode(generate_template))
  if not result:
    pagemsg("WARNING: Error generating forms, skipping")
    return
  tempargs = blib.split_generate_args(result)
  forms_seen = set()
  slots_and_forms_to_process = []
  for slot, formarg in tempargs.iteritems():
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
  for index, (slot, form) in blib.iter_items(sorted(slots_and_forms_to_process,
      key=lambda x: lalib.remove_macrons(x[1]))):
    def handler(page, index, parsed):
      return process_form(page, index, slot, form, pos)
    blib.do_edit(pywikibot.Page(site, lalib.remove_macrons(form)), index,
        handler, save=args.save, verbose=args.verbose, diff=args.diff)

parser = blib.create_argparser(u"Correct headers/headwords to reflect changes from noun to proper noun (and occasionally vice-versa)",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page)
