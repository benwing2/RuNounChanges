#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn == "%s-verb-old" % args.lang:
      origt = str(t)
      inf = getp("inf")
      if inf:
        t.add("head", inf, before="inf")
      rmparam(t, "inf")
      a = getp("a")
      if a == "p":
        a = "pf"
      elif a == "i":
        a = "impf"
      elif a in ["b", "p-i", "both"]:
        a = "both"
      else:
        pagemsg("WARNING: Bad aspect a=%s" % a)
        continue
      if a:
        t.add("a", a)
      else:
        rmparam(t, "a")
      aa = blib.fetch_param_chain(t, "aa")
      if aa:
        if a == "pf":
          blib.remove_param_chain(t, "aa")
          blib.set_param_chain(t, aa, "impf")
        elif a == "impf":
          blib.remove_param_chain(t, "aa")
          blib.set_param_chain(t, aa, "pf")
        else:
          pagemsg("WARNING: No aspect when aa= given")
          continue
      rmparam(t, "1")
      rmparam(t, "2")
      rmparam(t, "3")
      blib.set_template_name(t, "%s-verb" % args.lang)
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("rename {{%s-verb-old}} to {{%s-verb}} and standardize params" % (args.lang, args.lang))

  text = str(parsed)
  return text, notes

parser = blib.create_argparser("Rename {{cs-verb-old}}/{{sk-verb-old}} to {{cs-verb}}/{{sk-verb}} and clean/standardize parameters", include_pagefile=True, include_stdin=True)
parser.add_argument("--lang", choices=["cs", "sk"], help="Language of verbs (cs, sk).")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:%s-verb-old" % args.lang])
