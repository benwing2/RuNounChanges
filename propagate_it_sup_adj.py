#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, errandmsg, site

def process_lemma_page(page, index, form):
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
  it_adj_template = None
  it_part_template = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "it-adj":
      if it_adj_template:
        pagemsg("WARNING: Saw multiple adjective headword templates in subsection, %s and %s, skipping" % (
          str(it_adj_template), str(t)))
        return
      it_adj_template = t
    if tn == "it-pp":
      if it_part_template:
        pagemsg("WARNING: Saw multiple adjective headword templates in subsection, %s and %s, skipping" % (
          str(it_part_template), str(t)))
        return
      it_part_template = t
  if not it_adj_template and not it_part_template:
    pagemsg("WARNING: Didn't see adjective or participle lemma template")
    return None, None
  if it_part_template:
    if it_adj_template:
      pagemsg("WARNING: Saw both %s and %s, choosing adjective template" % (
        str(it_adj_template), str(it_part_template)))
      template = it_adj_template
    else:
      template = it_part_template
  else:
    template = it_adj_template
  if getparam(template, "sup"):
    pagemsg("Already saw sup=: %s" % str(template))
  else:
    origt = str(template)
    template.add("sup", form)
    pagemsg("Replaced %s with %s" % (origt, str(template)))
    notes.append("add sup=%s to {{%s}}" % (form, tname(template)))

  return str(parsed), notes

def process_text_on_non_lemma_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "superlative of" and getparam(t, "1") == "it":
      lemma = getparam(t, "2")
      def do_process(page, index, parsed):
        return process_lemma_page(page, index, pagetitle)
      blib.do_edit(pywikibot.Page(site, lemma), index,
          do_process, save=args.save, verbose=args.verbose, diff=args.diff)

parser = blib.create_argparser("Add sup= to {{it-adj}} headword params based on superlative entries",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_non_lemma_page, edit=True, stdin=True,
  default_cats=["Italian superlative adjectives"])
