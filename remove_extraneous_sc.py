#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

templates_with_sc = {
  "t": ["alt", "2"],
  "t+": ["alt", "2"],
  "t-": ["alt", "2"],
  "t+check": ["alt", "2"],
  "t-check": ["alt", "2"],
  "l": ["3", "2"],
  "link": ["3", "2"],
  "l-self": ["3", "2"],
  "ll": ["3", "2"],
  "m": ["3", "2"],
  "mention": ["3", "2"],
  "m-self": ["3", "2"],
  "m+": ["3", "2"],
}

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  global args

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn in templates_with_sc:
      if not t.has("sc"):
        continue
      lang = getparam(t, "1")
      sc = getparam(t, "sc")
      if not sc:
        rmparam(t, "sc")
        notes.append("remove blank sc= from {{%s}}" % tn)
      else:
        params_to_check = templates_with_sc[tn]
        if type(params_to_check) is not list:
          params_to_check = [params_to_check]
        for param in params_to_check:
          value_to_check = getparam(t, param)
          if value_to_check:
            break
        if not value_to_check:
          pagemsg("WARNING: For lang=%s, no displayable value, not removing sc=%s: %s" % (lang, sc, str(t)))
          continue
        detected_sc = expand_text("{{#invoke:scripts/templates|findBestScript|%s|%s}}" % (value_to_check, lang))
        if not detected_sc:
          continue
        if detected_sc == "ms-Arab" and sc == "Arab" and lang == "ms":
          pagemsg("Detected script ms-Arab for lang=ms, saw explicit sc=Arab, which is probably wrong, removing sc=: %s" % (str(t)))
        if detected_sc != sc:
          if len(detected_sc) >= 4 and len(sc) >= 4 and detected_sc[-4:] == sc[-4:]:
            pagemsg("For lang=%s, detected script %s, saw explicit sc=%s, both are variants of the same script, removing sc=: %s" % (lang, detected_sc, sc, str(t)))
          elif detected_sc == "None":
            pagemsg("WARNING: For lang=%s, detected script %s but saw explicit sc=%s, which may be right: %s" % (lang, detected_sc, sc, str(t)))
            continue
          else:
            force_detected_sc = expand_text("{{#invoke:scripts/templates|findBestScript|%s|%s|true}}" % (value_to_check, lang))
            if force_detected_sc == detected_sc:
              pagemsg("WARNING: For lang=%s, force-detected script %s but saw explicit sc=%s, explicit sc= probably wrong: %s" % (lang, detected_sc, sc, str(t)))
            else:
              pagemsg("WARNING: For lang=%s, detected script %s but force-detected %s and saw explicit sc=%s, which may be right: %s" % (lang, detected_sc, force_detected_sc, sc, str(t)))
            continue
        rmparam(t, "sc")
        notes.append("remove redundant sc=%s from {{%s}}" % (sc, tn))
    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))
  return parsed, notes

parser = blib.create_argparser("Remove redundant sc=", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
