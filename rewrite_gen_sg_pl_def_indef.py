#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

templates = {
  "genitive singular definite of": ["def", "gen", "s"],
  "genitive singular indefinite of": ["indef", "gen", "s"],
  "genitive plural definite of": ["def", "gen", "p"],
  "genitive plural indefinite of": ["indef", "gen", "p"],
}

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  text = str(page.text)

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  if blib.page_should_be_ignored(pagetitle):
    pagemsg("WARNING: Page should be ignored")
    return None, None

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)

    if tn in templates:
      infl_params = templates[tn]
      lang = getparam(t, "lang")
      if lang:
        has_lang = True
        term = getparam(t, "1")
        alt = getparam(t, "2")
        gloss = getparam(t, "3")
      else:
        has_lang = False
        lang = getparam(t, "1")
        term = getparam(t, "2")
        alt = getparam(t, "3")
        gloss = getparam(t, "4")
      params = []
      for param in t.params:
        pname = str(param.name).strip()
        pval = str(param.value).strip()
        if pname in ["lang", "1", "2", "3"] or (pname == "4" and not has_lang):
          continue
        pagemsg("WARNING: Unrecognized param %s, skipping" % pname)
        return None, None
      # Erase all params.
      del t.params[:]
      # Put back new params.
      blib.set_template_name(t, "inflection of")
      t.add("1", lang)
      t.add("2", term)
      t.add("3", alt)
      for index, tag in enumerate(infl_params):
        t.add(str(index + 4), tag)
      if gloss:
        t.add("t", gloss)
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("replace {{%s}} with {{inflection of}}" % tn)

  return str(parsed), notes

parser = blib.create_argparser("Rewrite 'genitive {singular/plural} {indefinite/definite}' to use {{inflection of}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in templates:
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save,
        verbose=args.verbose)
