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
        "noun", "nouns", "proper noun", "proper nouns"]:
      pos = getparam(t, "2")
      params = []
      for param in t.params:
        pname = str(param.name).strip()
        pval = str(param.value).strip()
        showkey = param.showkey
        if (pname not in ["1", "2", "head", "g", "g2", "g3", "3", "4", "5", "6", "7", "8", "9", "10"] or
            pname == "3" and pval not in ["masculine", "feminine"] or
            pname in ["5", "7", "9"] and pval != "or"):
          pagemsg("WARNING: head|bg|%s with extra param %s=%s: %s" % (pos, pname, pval, origt))
          break
      else: # no break
        rmparam(t, "1")
        rmparam(t, "2")
        m = []
        f = []
        head = getparam(t, "head")
        rmparam(t, "head")
        genders = []
        def process_gender(g):
          if g in ["m", "f", "n", "m-p", "f-p", "n-p", "p"]:
            genders.append(g)
          else:
            pagemsg("WARNING: Unrecognized gender '%s'" % g)
        g = getparam(t, "g")
        if g:
          process_gender(g)
        rmparam(t, "g")
        g2 = getparam(t, "g2")
        if g2:
          process_gender(g2)
        rmparam(t, "g2")
        g3 = getparam(t, "g3")
        if g3:
          process_gender(g3)
        rmparam(t, "g3")
        def handle_mf(array):
          array.append(getparam(t, "4"))
          rmparam(t, "3")
          rmparam(t, "4")
          i = 5
          while getparam(t, str(i)) == "or":
            array.append(getparam(t, str(i + 1)))
            rmparam(t, str(i))
            rmparam(t, str(i + 1))
            i += 2
        if getparam(t, "3") == "masculine":
          handle_mf(m)
        if getparam(t, "3") == "feminine":
          handle_mf(f)
        if pos in ["noun", "nouns"]:
          newtn = "bg-noun"
        else:
          newtn = "bg-proper noun"
        blib.set_template_name(t, newtn)
        t.add("1", head or pagetitle)
        blib.set_param_chain(t, genders, "2", "g")
        if m:
          blib.set_param_chain(t, m, "m", "m")
        if f:
          blib.set_param_chain(t, f, "f", "f")
        notes.append("convert {{head|bg|%s}} into {{%s}}" % (pos, newtn))
    elif tn in ["bg-noun", "bg-proper noun"]:
      g = None
      cur1 = getparam(t, "1")
      if cur1 in ["m", "f"]:
        g = cur1
      elif re.search("[a-zA-Z]", cur1):
        pagemsg("WARNING: Saw Latin in 1=%s in %s" % (cur1, origt))
        continue
      head = getparam(t, "head") or getparam(t, "sg")
      rmparam(t, "head")
      rmparam(t, "sg")
      genders = []
      def process_gender(g):
        if g in ["m", "f", "n", "m-p", "f-p", "n-p", "p"]:
          genders.append(g)
        elif g in ["mf", "fm"]:
          genders.append("m")
          genders.append("f")
        elif g in ["mn", "nm"]:
          genders.append("m")
          genders.append("n")
        elif g in ["fn", "nf"]:
          genders.append("f")
          genders.append("n")
        elif g in ["mfn", "fmn", "mnf", "nmf", "fnm", "nfm"]:
          genders.append("m")
          genders.append("f")
          genders.append("n")
        else:
          pagemsg("WARNING: Unrecognized gender '%s'" % g)
      if g:
        process_gender(g)
        rmparam(t, "1")
      g = getparam(t, "2")
      if g:
        process_gender(g)
      g = getparam(t, "g")
      if g:
        process_gender(g)
      rmparam(t, "g")
      g2 = getparam(t, "g2")
      if g2:
        process_gender(g2)
      rmparam(t, "g2")
      g3 = getparam(t, "g3")
      if g3:
        process_gender(g3)
      rmparam(t, "g3")
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
      blib.set_param_chain(t, genders, "2", "g")
      for pname, pval, showkey in params:
        t.add(pname, pval, showkey=showkey, preserve_spacing=False)
      if origt != str(t):
        notes.append("move head=/sg= to 1=, g= to 2= in {{%s}}" % tn)
    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))
  return parsed, notes

parser = blib.create_argparser("Fix Bulgarian noun headwords to new format",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Bulgarian proper nouns"], edit=1)
