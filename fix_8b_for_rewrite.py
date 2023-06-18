#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site

import rulib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    if str(t.name) in ["ru-conj", "ru-conj-old"]:
      param1 = getparam(t, "1")
      param2 = getparam(t, "2")
      if not param2.startswith("8b"):
        continue
      param3 = getparam(t, "3")
      param4 = getparam(t, "4")
      param5 = getparam(t, "5")
      assert not getparam(t, "6")
      if getparam(t, "past_m"):
        errmsg("WARNING: Has past_m=%s" % getparam(t, "past_m"))
      pap = getparam(t, "pap") or getparam(t, "past_adv_part")
      if pap:
        errmsg("WARNING: Has pap=%s" % pap)
      pap2 = getparam(t, "pap2") or getparam(t, "past_adv_part2")
      if pap2:
        errmsg("WARNING: Has pap2=%s" % pap2)
      param4 = rulib.make_unstressed_ru(param4)
      # Fetch non-numbered params.
      non_numbered_params = []
      for param in t.params:
        pname = str(param.name)
        if not re.search(r"^[0-9]+$", pname) and pname not in ["lang", "nocat", "tr"]:
          non_numbered_params.append((pname, param.value))
      # Erase all params.
      del t.params[:]
      # Put back numbered params.
      t.add("1", param1)
      t.add("2", param2)
      t.add("3", param3)
      t.add("4", param4)
      if param5:
        t.add("5", param5)
      # Put back non-numbered params.
      for name, value in non_numbered_params:
        t.add(name, value)
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))
      notes.append("rewrite class 8b verb to correspond to module changes")

  return str(parsed), notes

parser = blib.create_argparser("Rewrite class 8b verbs to correspond to module changes",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian class 8b verbs"])
