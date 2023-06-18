#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

import rulib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  text = str(page.text)
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn == "head" and getparam(t, "1") == "bg" and getparam(t, "2") in [
        "verb", "verbs", "adjective", "adjectives"]:
      pos = getparam(t, "2")
      if pos in ["verb", "verbs"]:
        newtn = "bg-verb"
      else:
        newtn = "bg-adj"
      params = []
      for param in t.params:
        pname = str(param.name).strip()
        pval = str(param.value).strip()
        showkey = param.showkey
        if (pname not in ["1", "2", "head", "g"] or
            pname == "g" and (newtn != "bg-adj" or pval != "m")):
          pagemsg("WARNING: head|bg|%s with extra param %s=%s: %s" % (pos, pname, pval, origt))
          break
      else: # no break
        rmparam(t, "1")
        rmparam(t, "2")
        rmparam(t, "g")
        head = getparam(t, "head")
        rmparam(t, "head")
        blib.set_template_name(t, newtn)
        t.add("1", rulib.remove_monosyllabic_accents(head or pagetitle))
        notes.append("convert {{head|bg|%s}} into {{%s}}" % (pos, newtn))
    elif tn == "bg-verb" or tn == "bg-adj":
      if tn == "bg-adj":
        g = getparam(t, "g")
        if g and g != "m":
          pagemsg("WARNING: Saw g=%s in %s" % (g, origt))
          continue
        if t.has("g"):
          rmparam(t, "g")
          notes.append("remove g=%s from {{%s}}" % (g, tn))
      head = getparam(t, "head") or getparam(t, "1")
      rmparam(t, "head")
      rmparam(t, "1")
      a = getparam(t, "a") or getparam(t, "2")
      rmparam(t, "a")
      rmparam(t, "2")
      if a in ["impf-pf", "pf-impf", "dual", "ip", "both"]:
        a = "both"
      elif a and a not in ["impf", "pf"]:
        pagemsg("WARNING: Unrecognized aspect %s in %s" % (a, origt))
      params = []
      for param in t.params:
        pname = str(param.name).strip()
        pval = str(param.value).strip()
        showkey = param.showkey
        if not pval:
          continue
        params.append((pname, pval, showkey))
      # Erase all params.
      del t.params[:]
      # Put back new params.
      t.add("1", rulib.remove_monosyllabic_accents(head or pagetitle))
      notes.append("move head= to 1= in {{%s}}" % tn)
      if a:
        t.add("2", a)
        notes.append("move a= to 2= in {{%s}}" % tn)
      for pname, pval, showkey in params:
        t.add(pname, pval, showkey=showkey, preserve_spacing=False)
    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))
  return parsed, notes

parser = blib.create_argparser("Fix Bulgarian verb/adjective headwords to new format",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Bulgarian adjectives", "Bulgarian verbs"], edit=1)
    #default_cats=["Bulgarian verbs", "Bulgarian adjectives"], edit=1)
