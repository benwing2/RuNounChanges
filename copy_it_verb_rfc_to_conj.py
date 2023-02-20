#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "it-verb-rfc" not in text:
    return

  parsed = blib.parse_text(text)

  it_verb_rfc_t = None
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = unicode(t)
    if tn == "it-verb-rfc":
      if it_verb_rfc_t:
        pagemsg("WARNING: Saw two headword templates %s and %s without intervening conjugation" % (
          unicode(it_verb_rfc_t), unicode(t)))
      it_verb_rfc_t = t
    elif tn == "it-conj" and it_verb_rfc_t:
      pagemsg("WARNING: Saw {{it-conj}} following {{it-verb-rfc}}: %s" % unicode(t))
    elif tn == "it-conj-rfc":
      it_verb_rfc_t = None
    elif tn.startswith("it-conj-"):
      if not it_verb_rfc_t:
        pagemsg("WARNING: Saw {{it-conj-*}} without preceding {{it-verb-rfc}}: %s" % unicode(t))
      else:
        conj = getparam(it_verb_rfc_t, "1")
        aux = getparam(t, "2")
        del t.params[:]
        if conj:
          t.add("1", conj)
        else:
          t.add("aux", aux)
        blib.set_template_name(t, "it-conj-rfc")
        notes.append("copy {{it-verb-rfc}} conjugation to {{it-conj-rfc}}")
        it_verb_rfc_t = None

  return unicode(parsed), notes

parser = blib.create_argparser("Copy {{it-verb-rfc}} conjugation to {{it-conj-rfc}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:it-verb"])
