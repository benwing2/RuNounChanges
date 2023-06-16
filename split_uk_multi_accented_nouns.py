#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import uklib

AC = u"\u0301"

def split_multi_accented_word(word):
  retval = []
  for w in re.split(r",\s*", word):
    if AC not in w:
      retval.append(w)
    for i, char in enumerate(w):
      if char == AC:
        retval.append(w[0:i].replace(AC, "") + AC + w[i+1:].replace(AC, ""))
  return retval

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  head = None
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "uk-noun":
      head = getparam(t, "1")
      headvals = split_multi_accented_word(head)
      if len(headvals) > 2:
        pagemsg("WARNING: Can't handle 3-way split: %s" % origt)
      elif len(headvals) == 2:
        t.add("1", headvals[0])
        t.add("head2", headvals[1], before="2")
      gen = getparam(t, "3")
      genvals = split_multi_accented_word(gen)
      if len(genvals) > 2:
        pagemsg("WARNING: Can't handle 3-way split: %s" % origt)
      elif len(genvals) == 2:
        t.add("3", genvals[0])
        t.add("gen2", genvals[1], before="4")
      pl = getparam(t, "4")
      plvals = split_multi_accented_word(pl)
      if len(plvals) > 2:
        pagemsg("WARNING: Can't handle 3-way split: %s" % origt)
      elif len(plvals) == 2:
        t.add("4", plvals[0])
        t.add("pl2", plvals[1])
    elif tn in ["uk-decl-noun", "uk-decl-noun-unc", "uk-decl-noun-pl"]:
      maxparam = 14 if tn == "uk-decl-noun" else 7
      for i in range(1, maxparam + 1):
        form = getparam(t, str(i))
        formvals = split_multi_accented_word(form)
        if len(formvals) > 1:
          t.add(str(i), ", ".join(formvals))

    if origt != str(t):
      notes.append("split multi-stressed forms in {{%s}}" % tn)
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser(u"Split multi-stressed Ukrainian noun forms",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
