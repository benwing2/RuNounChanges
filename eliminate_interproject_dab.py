#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

wikipedia_box_templates = ["wikipedia", "wp", "slim-wikipedia", "swp"]
interproject_templates_lang_in_1 = ["R:wbooks", "R:wnews", "R:wquote", "R:wsource", "R:wversity", "R:wvoyage"]
interproject_templates_lang_in_lang = ["pedia", "specieslite", "comcatlite", "R:commons", "R:metawiki", "R:wikidata"]

def process_text_on_page(index, pagetitle, pagetext):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  notes = []

  parsed = blib.parse_text(pagetext)
  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    origt = str(t)
    tn = tname(t)
    if tn in wikipedia_box_templates or tn in interproject_templates_lang_in_1 or tn in interproject_templates_lang_in_lang:
      if t.has("disambiguation"):
        dab = getp("disambiguation")
        if not dab:
          rmparam(t, "disambiguation")
          notes.append("remove blank disambiguation= from {{%s}}" % tn)
        else:
          t.add("dab", dab, before="disambiguation")
          rmparam(t, "disambiguation")
          notes.append("move disambiguation= to dab= in {{%s}}" % tn)
      if t.has("dab"):
        dab = getp("dab")
        if not dab:
          rmparam(t, "dab")
          notes.append("remove blank dab= from {{%s}}" % tn)
        else:
          if tn in interproject_templates_lang_in_1:
            term = getp("2") or dab
            alt = getp("3") or getp("2") or dab
            if alt == term:
              alt = ""
            if term == pagetitle or term == "{{PAGENAME}}":
              term = ""
            lang = getp("1")
            named_params = []
            for param in t.params:
              pn = pname(param)
              pv = str(param.value)
              if pn not in ["1", "2", "3", "dab"]:
                named_params.append((pn, pv))
            del t.params[:]
            if lang or term or alt:
              t.add("1", lang)
            if term or alt:
              t.add("2", term)
            if alt:
              t.add("3", alt)
            for pn, pv in named_params:
              t.add(pn, pv, preserve_spacing=False)
            notes.append("eliminate dab= in {{%s}}" % tn)
          elif tn in interproject_templates_lang_in_lang or tn in wikipedia_box_templates:
            if tn in interproject_templates_lang_in_lang:
              term = getp("1") or dab
            else:
              term = dab or getp("1")
            alt = getp("2") or getp("1") or dab
            if alt == term:
              alt = ""
            if term == pagetitle or term == "{{PAGENAME}}":
              term = ""
            named_params = []
            for param in t.params:
              pn = pname(param)
              pv = str(param.value)
              if pn not in ["1", "2", "dab"]:
                named_params.append((pn, pv))
            del t.params[:]
            if term or alt:
              t.add("1", term)
            if alt:
              t.add("2", alt)
            for pn, pv in named_params:
              t.add(pn, pv, preserve_spacing=False)
            notes.append("eliminate dab= in {{%s}}" % tn)

    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes
  
parser = blib.create_argparser("Eliminate dab= in interproject templates", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
