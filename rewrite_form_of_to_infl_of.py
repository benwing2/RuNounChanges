#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

templates = {
#  "genitive singular definite of": ["def", "gen", "s"],
#  "genitive singular indefinite of": ["indef", "gen", "s"],
#  "genitive plural definite of": ["def", "gen", "p"],
#  "genitive plural indefinite of": ["indef", "gen", "p"],
  "dative singular of": ["dat", "s"],
  "dative plural of": ["dat", "p"],
  "dative of": ["dat"],
  "genitive singular of": ["gen", "s"],
  "genitive plural of": ["gen", "p"],
  "genitive of": ["gen"],
}

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    def getp(param):
      return getparam(t, param)

    if tn in templates:
      infl_params = templates[tn]
      lang = getp("1")
      term = getp("2")
      alt = getp("3") or getp("alt")
      gloss = getp("4") or getp("t") or getp("gloss")
      tr = getp("tr")
      g = getp("g")
      pos = getp("pos")
      sc = getp("sc")
      params = []
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "4", "alt", "t", "gloss", "tr", "g", "pos", "sc"]:
          pagemsg("WARNING: Unrecognized param %s=%s, skipping: %s" % (pn, str(param.value), str(t)))
          return
      # Erase all params.
      del t.params[:]
      # Put back new params.
      blib.set_template_name(t, "infl of")
      t.add("1", lang)
      t.add("2", term)
      t.add("3", alt)
      for ind, tag in enumerate(infl_params):
        t.add(str(ind + 4), tag)
      if tr:
        t.add("tr", tr)
      if gloss:
        t.add("t", gloss)
      if g:
        t.add("g", g)
      if pos:
        t.add("pos", pos)
      if sc:
        t.add("sc", sc)
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("replace {{%s}} with {{infl of|...|%s}}" % (tn, "|".join(infl_params)))

  return str(parsed), notes

parser = blib.create_argparser("Rewrite more specific form-of templates to use {{inflection of}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  default_refs=["Template:%s" % template for template in templates],
  edit=True, stdin=True)
