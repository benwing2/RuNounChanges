#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

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
    origt = str(t)
    if tn == "it-verb-rfc":
      if it_verb_rfc_t:
        pagemsg("WARNING: Saw two headword templates %s and %s without intervening conjugation" % (
          str(it_verb_rfc_t), str(t)))
      it_verb_rfc_t = t
    elif tn == "it-conj" and it_verb_rfc_t:
      pagemsg("WARNING: Saw {{it-conj}} following {{it-verb-rfc}}: %s" % str(t))
    elif tn == "it-conj-rfc":
      it_verb_rfc_t = None
    elif tn.startswith("it-conj-"):
      if not it_verb_rfc_t:
        pagemsg("WARNING: Saw {{it-conj-*}} without preceding {{it-verb-rfc}}: %s" % str(t))
      else:
        conj = getparam(it_verb_rfc_t, "1")
        newconj = None
        aux = getparam(t, "2")
        if conj.startswith("?/"):
          if aux == "avere":
            conjaux = "a"
          elif aux == "essere":
            conjaux = "e"
          elif aux == "avere or essere":
            conjaux = "a:e"
          elif aux == "essere or avere":
            conjaux = "e:a"
          else:
            pagemsg("WARNING: Can't parse auxiliary '%s': %s" % (aux, str(t)))
            conjaux = None
          if conjaux:
            newconj = conjaux + conj[1:]
        must_continue = False
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if pn not in ["1", "2"]:
            pagemsg("WARNING: Unrecognized param %s=%s in old conjugation: %s" % (pn, pv, str(t)))
            must_continue = True
            break
        if must_continue:
          continue
        if newconj:
          it_verb_rfc_t.add("1", newconj)
          notes.append("update {{it-verb-rfc}} based on auxiliary in old {{it-conj-*}} template")
          conj = newconj
        del t.params[:]
        if conj:
          trimmed_conj = re.sub(r"\[r:[^\[\]]*\]", "", conj)
          if trimmed_conj != conj:
            pagemsg("Trimmed out references from conjugation '%s', producing '%s'" % (conj, trimmed_conj))
            conj = trimmed_conj
          t.add("1", conj)
        else:
          t.add("aux", aux)
        blib.set_template_name(t, "it-conj-rfc")
        notes.append("copy {{it-verb-rfc}} conjugation to {{it-conj-rfc}}")
        it_verb_rfc_t = None

  return str(parsed), notes

parser = blib.create_argparser("Copy {{it-verb-rfc}} conjugation to {{it-conj-rfc}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:it-verb"])
