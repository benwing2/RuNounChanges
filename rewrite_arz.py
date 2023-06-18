#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

import blib, pywikibot
from blib import msg, getparam, addparam, rmparam

def rewrite_one_page_arz_headword(page, index, text):
  temps_changed = []
  for t in text.filter_templates():
    if str(t.name) == "arz-noun":
      head = getparam(t, "head")
      rmparam(t, "head")
      tr = getparam(t, "tr")
      rmparam(t, "tr")
      sort = getparam(t, "sort")
      rmparam(t, "sort")
      g = getparam(t, "g")
      rmparam(t, "g")
      g2 = getparam(t, "g2")
      rmparam(t, "g2")
      pl = getparam(t, "2")
      rmparam(t, "2")
      pltr = getparam(t, "3")
      rmparam(t, "3")
      addparam(t, "1", head)
      addparam(t, "2", g)
      if g2:
        addparam(t, "g2", g2)
      if tr:
        addparam(t, "tr", tr)
      if pl:
        addparam(t, "pl", pl)
      if pltr:
        addparam(t, "pltr", pltr)
      if sort:
        addparam(t, "sort", sort)
      temps_changed.append("arz-noun")
    elif str(t.name) == "arz-adj":
      head = getparam(t, "head")
      rmparam(t, "head")
      tr = getparam(t, "tr")
      rmparam(t, "tr")
      sort = getparam(t, "sort")
      rmparam(t, "sort")
      pl = getparam(t, "pwv") or getparam(t, "p")
      rmparam(t, "pwv")
      rmparam(t, "p")
      pltr = getparam(t, "ptr")
      rmparam(t, "ptr")
      f = getparam(t, "fwv") or getparam(t, "f")
      rmparam(t, "fwv")
      rmparam(t, "f")
      ftr = getparam(t, "ftr")
      rmparam(t, "ftr")
      addparam(t, "1", head)
      if tr:
        addparam(t, "tr", tr)
      if f:
        addparam(t, "f", f)
      if ftr:
        addparam(t, "ftr", ftr)
      if pl:
        addparam(t, "pl", pl)
      if pltr:
        addparam(t, "pltr", pltr)
      if sort:
        addparam(t, "sort", sort)
      temps_changed.append("arz-adj")
  return text, "rewrite %s to new style" % ", ".join(temps_changed)

def rewrite_arz_headword(save, verbose, startFrom, upTo):
  for cat in ["Egyptian Arabic adjectives", "Egyptian Arabic nouns"]:
    for index, page in blib.cat_articles(cat, startFrom, upTo):
      blib.do_edit(page, index, rewrite_one_page_arz_headword, save=save,
          verbose=verbose)

pa = blib.create_argparser("Rewrite Egyptian Arabic headword templates")
params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

rewrite_arz_headword(params.save, params.verbose, startFrom, upTo)
