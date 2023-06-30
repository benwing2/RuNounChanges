#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site

templates_to_tags = {
  "sv-verb-form-imp": ["imp"],
  "sv-verb-form-past": ["past"],
  "sv-verb-form-past-pass": ["past", "pass"],
  "sv-verb-form-pre": ["pres"],
}

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  replacements = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    repl = None
    if tn in templates_to_tags:
      tags = templates_to_tags[tn]
    else:
      continue
    plural_of = getp("plural of")
    term = getp("1")
    must_continue = False
    for param in t.params:
      ok = False
      pn = pname(param)
      if pn not in ["1", "plural of"]:
        pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, str(param.value), str(t)))
        must_continue = True
        break
    if must_continue:
      continue
    origt = str(t)
    repl = "{{infl of|sv|%s||%s}}" % (term, "|".join(tags))
    if plural_of:
      repl = "{{sv-obs verb pl|%s}}, %s" % (plural_of, repl)
    repltuple = (origt, repl)
    if repltuple not in replacements:
      replacements.append(repltuple)
    if plural_of:
      notes.append("convert {{%s|plural of=...}} to {{sv-obs verb pl|...}}, {{infl of|sv|...}}")
    else:
      notes.append("convert {{%s}} to {{infl of|sv|...}}")

  for origt, replt in replacements:
    text, did_replace = blib.replace_in_text(text, origt, replt, pagemsg)
    if not did_replace:
      return

  return text, notes

parser = blib.create_argparser(
  "Convert {{sv-verb-form-*}} optionally with |plural of= param to generic equivalents",
  include_pagefile=True, include_stdin=True
)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(
  args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:%s" % temp for temp in templates_to_tags]
)

