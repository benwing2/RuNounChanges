#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  head_template_tr = None
  head_auto_tr = None
  noun_head_template = None
  saw_ndecl = False
  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    origt = str(t)
    if tn == "head":
      langcode = getp("1")
      form = getp("head") or pagetitle
    elif tn == "plural of":
      langcode = getp("1")
      form = getp("3") or getp("2")
    else:
      continue
    if not form:
      continue
    tr = getp("tr")
    if not tr:
      continue
    if tn == "head":
      tndesc = "{{%s|%s|%s}}" % (tn, langcode, getp("2"))
    else:
      tndesc = "{{%s|%s}}" % (tn, langcode)
    multi_trs = False
    for i in range(2, 10):
      if getparam(t, "tr%s" % i):
        multi_trs = True
        # We might have tr=some special translit and tr2=the default one, and in that case
        # we don't want to remove tr2= even though it appears redundant.
        pagemsg("WARNING: Multiple translits, not changing: %s" % str(t))
        break
    if multi_trs:
      continue
    autotr = expand_text("{{xlit|%s|%s}}" % (langcode, form))
    if autotr is not None:
      if autotr == tr:
        pagemsg("Removing redundant translit tr=%s for form %s" % (tr, form))
        rmparam(t, "tr")
        notes.append("remove redundant tr=%s from %s" % (tr, tndesc))
      else:
        pagemsg("Page has non-redundant translit tr=%s vs. auto-tr=%s in %s" % (tr, autotr, tndesc))
    if str(t) != origt:
      pagemsg("Replace %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Remove redundant translit from {{head}} and {{plural of}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
