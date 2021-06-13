#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

conjugations = {}

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "it-verb" not in text:
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = unicode(t)
    def getp(param):
      return getparam(t, param)
    if tn in ["it-verb"]:
      pagemsg("Saw %s" % unicode(t))
      if pagetitle.endswith("re"):
        param1 = getp("1")
        if not param1:
          pagemsg("Didn't see 1= in non-reflexive {{it-verb}}: %s" % unicode(t))
          continue
        refl_pagetitle = re.sub("rre$", "rsi", pagetitle)
        refl_pagetitle = re.sub("re$", "rsi", refl_pagetitle)
        param1 = re.sub(r"^(?:\[.*?\]|[^\[\]])*?([/\\])", lambda m: "\\" if m.group(1) == "\\" else "", param1)
        if re.search("[aei]rre$", pagetitle):
          param1 += ".rre"
        if "/" in param1:
          pagemsg("WARNING: Something wrong, saw / after attempting to remove it: %s" % param1)
          continue
        if refl_pagetitle in conjugations:
          existing_conj = conjugations[refl_pagetitle]
          if existing_conj is None:
            pagemsg("WARNING: Already saw two or more conjugations and saw a third one <%s>, skipping" % param1)
            continue
          if existing_conj != param1:
            pagemsg("WARNING: Saw two conjugations <%s> and <%s>" % (existing_conj, param1))
            conjugations[refl_pagetitle] = None
            continue
        conjugations[refl_pagetitle] = param1
      elif pagetitle.endswith("rsi"):
        param1 = getp("1")
        if param1:
          pagemsg("Already saw conjugation: %s" % param1)
          continue
        if pagetitle not in conjugations:
          pagemsg("WARNING: Didn't see conjugation")
          continue
        conj = conjugations[pagetitle]
        if conj is None:
          pagemsg("WARNING: Can't set conjugation because non-reflexive equivalent has multiple conjugations")
          continue
        if ".imp:" in conj:
          pagemsg("WARNING: Saw imperative in conjugation, needs manual fixing: %s" % conj)
          continue
        t.add("1", conj)
        notes.append("copy non-reflexive conjugation to reflexive conjugation")
      else:
        pagemsg("WARNING: Saw {{it-verb}} on page not ending in -re or -rsi: %s" % unicode(t))
    if unicode(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Copy non-reflexive {{it-verb}} conjugation to corresponding reflexive conjugation",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:it-verb"])
