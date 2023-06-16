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

  if "pt-pp" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn == "pt-pp":
      origt = str(t)
      must_continue = False
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn not in ["1", "2"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, pv, str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      rmparam(t, "2")
      rmparam(t, "1")
      if re.search("[as]$", pagetitle):
        blib.set_template_name(t, "head")
        t.add("1", "pt")
        t.add("2", "past participle form")
        notes.append("convert {{pt-pp}} for participle form to {{head|pt|past participle form}}")
      else:
        notes.append("convert {{pt-pp}} to new syntax")
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  text = str(parsed)
  newtext = re.sub(r"==Verb(==+\n\{\{(?:pt-pp[|}]|head\|pt\|(?:past )?participle))", r"==Participle\1", text)
  if text != newtext:
    notes.append("replace ==Verb== with ==Participle== for participles and participle forms")
    text = newtext

  return text, notes

parser = blib.create_argparser("Convert {{pt-pp}} templates to new syntax and use {{head|pt|past participle form}} where appropriate",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:pt-pp"])
