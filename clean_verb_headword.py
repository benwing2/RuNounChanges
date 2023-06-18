#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  actions_taken = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    paramschanged = []
    if tn in ["ar-verb"]:
      form = getparam(t, "form")
      if form == "1" or form == "I":
        pagemsg("skipped ar-verb because form I")
        continue
      elif getparam(t, "useparam"):
        pagemsg("skipped ar-verb because useparam")
        continue
      def remove_param(param):
        if t.has(param):
          t.remove(param)
          paramschanged.append(param)
      remove_param("head")
      remove_param("head2")
      remove_param("head3")
      remove_param("tr")
      remove_param("impf")
      remove_param("impfhead")
      remove_param("impftr")
      if getparam(t, "sc") == "Arab":
        remove_param("sc")
      I = getparam(t, "I")
      if I in [u"ء", u"و", u"ي"] and form not in ["8", "VIII"]:
        pagemsg("form=%s, removing I=%s" % (form, I))
        remove_param("I")
      II = getparam(t, "II")
      if (II == u"ء" or II in [u"و", u"ي"] and
          form in ["2", "II", "3", "III", "5", "V", "6", "VI"]):
        pagemsg("form=%s, removing II=%s" % (form, II))
        remove_param("II")
      III = getparam(t, "III")
      if III == u"ء":
        pagemsg("form=%s, removing III=%s" % (form, III))
        remove_param("III")
      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))
      if len(paramschanged) > 0:
        actions_taken.append("form=%s (%s)" % (form, ', '.join(paramschanged)))
  changelog = "ar-verb: remove params: %s" % '; '.join(actions_taken)
  return str(parsed), changelog

parser = blib.create_argparser("Clean up Arabic vevrb headword templates", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats = ["Arabic verbs"])
