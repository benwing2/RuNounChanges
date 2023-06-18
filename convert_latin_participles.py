#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    allow_2 = False
    lemma = None
    if tn in ["la-future participle", "la-perfect participle", "la-gerundive"]:
      base = getparam(t, "1")
      if tn == "la-gerundive":
        param2 = getparam(t, "2")
        if param2:
          if lalib.remove_macrons(base) == lalib.remove_macrons(param2):
            allow_2 = True
            base = param2
          else:
            pagemsg("WARNING: Unrecognized param 2: %s" % origt)
            continue
      if not base:
        pagemsg("WARNING: Empty param 1: %s" % origt)
        continue
      lemma = base + "us"
    elif tn == "la-present participle":
      base = getparam(t, "1")
      ending = getparam(t, "2")
      if not base:
        pagemsg("WARNING: Empty param 1: %s" % origt)
        continue
      if not ending:
        pagemsg("WARNING: Empty param 2: %s" % origt)
        continue
      if ending == "ans":
        lemma = base + u"āns"
      elif ending == "ens":
        lemma = base + u"ēns"
      elif ending == "iens":
        lemma = u"%siēns/%seunt" % (base, base)
      else:
        pagemsg("WARNING: Unrecognized param 2: %s" % origt)
        continue
      allow_2 = True
    if lemma:
      bad_param = False
      for param in t.params:
        pname = str(param.name)
        if pname.strip() == "1" or allow_2 and pname.strip() == "2":
          continue
        pagemsg("WARNING: Unrecognized param %s=%s: %s" % (
          pname, param.value, origt))
        bad_param = True
      if bad_param:
        continue
      rmparam(t, "2")
      t.add("1", lemma)
      blib.set_template_name(t, "la-part")
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append(u"convert {{%s}} to {{la-part}}" % tn)

  return str(parsed), notes

parser = blib.create_argparser(u"Convert Latin participle headwords to use {{la-part}}",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Latin participles"], edit=True)
