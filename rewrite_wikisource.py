#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname
from collections import defaultdict

seen_projects = defaultdict(int)

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if blib.page_should_be_ignored(pagetitle):
    return

  if not args.stdin:
    pagemsg("Processing")

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn == "source":
      term = getp("1")
      alt = getp("2")
      origlang = getp("lang")
      lang = origlang or "en"
      named_params = []
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn not in ["1", "2", "lang"]:
          named_params.append((pn, pv))
      del t.params[:]
      t.add("1", lang)
      if term or alt:
        t.add("2", term)
      if alt:
        t.add("3", alt)
      for pn, pv in named_params:
        t.add(pn, pv, preserve_spacing=False)
      blib.set_template_name(t, "R:wsource")
      if not origlang:
        notes.append("rename {{source}} -> {{R:wsource|en}}")
      else:
        notes.append("rename {{source|lang=%s}} -> {{R:wsource|%s}}" % (lang, lang))

    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser(u"Rewrite {{source}} to {{R:wsource}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True, default_refs=["Template:source"])
