#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

AC = u"\u0301"

def is_monosyllabic(word):
  return len(re.sub(u"[^аеиоуяюъ]", "", word)) <= 1

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "uk-conj-manual":
      aspect = getparam(t, "1")
      t.add("aspect", aspect, before="1", preserve_spacing=False)
      rmparam(t, "1")
      for param in t.params:
        pn = pname(param)
        if "_futr_" in pn:
          param.name = pn.replace("_futr_", "_fut_")
      to_fix = []
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn.endswith("2"):
          to_fix.append((pn, pv))
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn.endswith("3"):
          to_fix.append((pn, pv))
      for pn, pv in to_fix:
        if pv.strip() and pv.strip() not in ["-", u"—"]:
          existing = getparam(t, pn[:-1])
          if not existing:
            existing = pv
          else:
            existing = re.sub(r"(\s*)$", r", %s\1" % pv.strip(), existing)
            t.add(pn[:-1], existing, preserve_spacing=False)
        rmparam(t, pn)
      blib.set_template_name(t, "uk-conj-table")
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("convert {{%s}} to {{uk-conj-table}}" % tn)

  return str(parsed), notes

parser = blib.create_argparser(u"Convert Ukrainian {{uk-conj-manual}} to {{uk-conj-table}}",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_refs=["Template:uk-conj-manual"], edit=True)
