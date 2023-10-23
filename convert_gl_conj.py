#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json, unicodedata

import blib
from blib import getparam, rmparam, getrmparam, tname, pname, msg, errandmsg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "gl-verb-old" not in text:
    return

  parsed = blib.parse_text(text)

  headt = None
  saw_headt = False

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    if tn == "gl-verb-old":
      pagemsg("Saw %s" % str(t))
      saw_headt = True
      if headt:
        pagemsg("WARNING: Saw multiple head templates: %s and %s" % (str(headt), str(t)))
        return
      headt = t
    elif tn == "gl-conj":
      if not headt:
        pagemsg("WARNING: Saw conjugation template without {{gl-verb-old}} head template: %s" % str(t))
        return
      orig_headt = str(headt)
      headtn = tname(headt)
      # Erase all params
      del headt.params[:]
      param1 = getp("1")
      if param1:
        headt.add("1", param1)
      blib.set_template_name(headt, "gl-verb")
      notes.append("convert {{%s|...}} to %s" % (headtn, str(headt)))
      headt = None

  if not saw_headt:
    pagemsg("WARNING: Didn't see {{gl-verb-old}} head template")
    return

  return str(parsed), notes

parser = blib.create_argparser("Copy Galician verb conj to headword", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  default_cats=["Galician verbs"], edit=True, stdin=True)
