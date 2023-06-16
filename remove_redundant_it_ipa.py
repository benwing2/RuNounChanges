#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
  def getpron(pron):
    return expand_text("{{#invoke:it-pronunciation|to_phonemic_bot|%s}}" % pron)

  notes = []

  if "it-IPA" not in text:
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn in ["it-IPA"]:
      pagemsg("Saw %s" % str(t))
      default_pron_phonemic = None
      prons = []
      for i in range(1, 11):
        pron = getparam(t, str(i))
        if pron:
          prons.append(pron)
      if not prons:
        prons == ["+"]
      defaulted_prons = []
      for pron in prons:
        def add(prn):
          if prn not in defaulted_prons:
            defaulted_prons.append(prn)
        if pron == "+" or pron == pagetitle:
          add("+")
        elif len(pron) == 1: # vowel only
          add(pron)
        else: # full pronun
          pron_phonemic = None
          if default_pron_phonemic is None:
            default_pron_phonemic = getpron(pagetitle)
          if default_pron_phonemic:
            pron_phonemic = getpron(pron)
            if not pron_phonemic:
              add(pron)
              continue
            if default_pron_phonemic == pron_phonemic:
              pron = "+"
          if pron != "+":
            if pron_phonemic is None:
              pron_phonemic = getpron(pron)
            if not pron_phonemic:
              add(pron)
              continue
            single_vowel_spec = re.sub(u"[^àèéìòúù]", "", pron)
            if len(single_vowel_spec) == 1:
              single_vowel_pron_phonemic = getpron(single_vowel_spec)
              if single_vowel_pron_phonemic == pron_phonemic:
                pron = single_vowel_spec
          add(pron)
      if defaulted_prons == ["+"]:
        blib.remove_param_chain(t, "1", "")
        if str(t) != origt:
          notes.append("remove redundant respelling(s) from {{it-IPA}}")
      else:
        blib.set_param_chain(t, defaulted_prons, "1", "")
        if str(t) != origt:
          notes.append("replace default respelling(s) with single-vowel spec or '+' in {{it-IPA}}")
      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Remove redundant respellings in {{it-IPA}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:it-IPA"])
