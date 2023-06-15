#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, errandmsg, site

import lalib

import convert_la_headword_noun

def process_page(page, index, parsed):
  global args
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
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
    must_continue = False
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "la-adj":
        if la_adj_template:
          pagemsg("WARNING: Saw multiple adjective headword templates in subsection, %s and %s, skipping" % (
            unicode(la_adj_template), unicode(t)))
          must_continue = True
          break
        la_adj_template = t
        saw_a_template = True
    if must_continue:
      continue
    if not la_adj_template:
      continue
    m = re.search(r"'*comparative'*: '*(.*?)'+,* *'*superlative'*: '*(.*?)'+", subsections[k])
    if m:
      comp, sup = m.groups()
      def parse_comp_sup(cs):
        m = re.search(r"^\{\{[lm]\|la\|(.*?)\}\}$", cs)
        if m:
          return m.group(1)
        m = re.search(r"^\[\[.*?\|(.*?)\]\]$", cs)
        if m:
          return m.group(1)
        m = re.search(r"^\[\[(.*?)\]\]$", cs)
        if m:
          return m.group(1)
        pagemsg("WARNING: Can't parse comp/sup %s" % cs)
        return None
      comp = parse_comp_sup(comp)
      sup = parse_comp_sup(sup)
      if comp and sup:
        orig_la_adj_template = unicode(la_adj_template)
        la_adj_template.add("comp", comp)
        la_adj_template.add("sup", sup)
        pagemsg("Replaced %s with %s" % (orig_la_adj_template, unicode(la_adj_template)))
        notes.append("move comparative/superative to {{la-adj}} headword params")
        subsections[k] = unicode(parsed)
        subsections[k] = re.sub(r"\n+\* *'*comparative'*: '*(.*?)'+,* *'*superlative'*: '*(.*?)'+\n+", "\n\n", subsections[k], 1)

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Move comparative/superlative to {{la-adj}} headword params",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Latin adjectives"], edit=True)
