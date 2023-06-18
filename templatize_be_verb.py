#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []
  pagemsg("Processing")

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "head" and getparam(t, "1") == "be" and getparam(t, "2") == "verb":
      head = getparam(t, "head") or pagetitle
      tr = getparam(t, "tr")
      aspect = getparam(t, "3")
      if aspect == "imperfective":
        aspect = "impf"
      elif aspect == "perfective":
        aspect = "pf"
      else:
        pagemsg("WARNING: Unrecognized aspect %s: %s" % (aspect, origt))
        continue
      if getparam(t, "4"):
        pagemsg("WARNING: Unrecognized value in 4=: %s" % origt)
        continue
      p5 = getparam(t, "5")
      if p5 and p5 not in ["imperfective", "perfective"]:
        pagemsg("WARNING: Unrecognized value in 5=: %s" % origt)
        continue
      other_aspect = None
      if p5 == "imperfective":
        other_aspect = "impf"
      elif p5 == "perfective":
        other_aspect = "pf"
      if p5:
        other_verb = getparam(t, "6")

      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "4", "5", "6", "head", "tr",
            # params to ignore
            "sc"]:
          pagemsg("WARNING: Unrecognized param %s=%s, skipping: %s" %
              (pn, str(param.value), origt))
          must_continue = True
          break
      if must_continue:
        continue

      del t.params[:]
      blib.set_template_name(t, "be-verb")
      t.add("1", head)
      if tr:
        t.add("tr", tr)
      t.add("2", aspect)
      if other_aspect:
        t.add(other_aspect, other_verb)
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("convert {{head|be|verb}} to {{be-verb}}")
  return str(parsed), notes

parser = blib.create_argparser("Convert {{head|be|verb}} to {{be-verb}}", include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Belarusian verbs"], edit=True)
