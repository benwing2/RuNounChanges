#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, errandmsg, site

import lalib

def process_lemma_page(page, index, is_comp, form):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)

  notes = []

  parsed = blib.parse_text(text)
  la_adj_template = None
  la_part_template = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "la-adj":
      if la_adj_template:
        pagemsg("WARNING: Saw multiple adjective headword templates in subsection, %s and %s, skipping" % (
          str(la_adj_template), str(t)))
        return None, None
      la_adj_template = t
    if tn == "la-part":
      if la_part_template:
        pagemsg("WARNING: Saw multiple adjective headword templates in subsection, %s and %s, skipping" % (
          str(la_part_template), str(t)))
        return None, None
      la_part_template = t
  if not la_adj_template and not la_part_template:
    pagemsg("WARNING: Didn't see adjective or participle lemma template")
    return None, None
  if is_comp:
    param = "comp"
  else:
    param = "sup"
  if la_part_template:
    if la_adj_template:
      pagemsg("WARNING: Saw both %s and %s, choosing adjective template" % (
        str(la_adj_template), str(la_part_template)))
      template = la_adj_template
    else:
      template = la_part_template
  else:
    template = la_adj_template
  if getparam(template, param):
    pagemsg("Already saw %s=: %s" % (param, str(template)))
  else:
    orig_template = str(template)
    if param == "comp":
      template.add(param, form, before="sup")
    else:
      template.add(param, form)
    pagemsg("Replaced %s with %s" % (orig_template, str(template)))
    notes.append("add %s=%s to {{la-adj}}" % (param, form))

  return str(parsed), notes

def process_non_lemma_page(page, index):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  pagemsg("Processing")
  text = str(page.text)
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["la-adj-comp", "la-adj-sup"]:
      lemma = getparam(t, "1") or pagetitle
      pos = getparam(t, "pos")
      if pos:
        def do_process(page, index, parsed):
          return process_lemma_page(page, index, tn == "la-adj-comp",
              lemma)
        blib.do_edit(pywikibot.Page(site, lalib.remove_macrons(pos)), index,
            do_process, save=args.save, verbose=args.verbose, diff=args.diff)
      else:
        pagemsg("WARNING: Didn't see positive degree: %s" % str(t))

parser = blib.create_argparser("Add comp/sup to {{la-adj}} headword params based on comparative/superlative entries",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_non_lemma_page,
  default_cats=["Latin comparative adjectives", "Latin superlative adjectives"])
