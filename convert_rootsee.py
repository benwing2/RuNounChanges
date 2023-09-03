#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata

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
    origt = str(t)
    if tn == "rootsee":
      source = ""
      dest = getp("1")
      root = getp("2")
      arg3 = getp("3")
      id = getp("t")
      if arg3 in ["ine-pro", "PIE"]:
        source = "ine"
      elif dest in ["ine-pro", "PIE"]:
        dest = ""
      elif dest in ["nv", "ar", "mt", "akk", "tzm", "he", "pi"]:
        source = ""
      else:
        source = "ine"
      del t.params[:]
      if dest:
        t.add("1", dest)
      if source or dest:
        t.add("2", source)
      if root or source or dest:
        t.add("3", root)
      if id:
        t.add("id", id)
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("convert {{rootsee}} to new format")
    elif tn == "PIE root see":
      for param in t.params:
        pn = pname(param)
        if pn not in ["id"]:
          pagemsg("WARNING: Unrecognized param %s=%s in %s" % (pn, str(param.value), str(t)))
          break
      else: # no break
        blib.set_template_name(t, "rootsee")
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("convert {{PIE root see}} to {{rootsee}}")

  return str(parsed), notes

parser = blib.create_argparser("Convert {{rootsee}} and {{PIE root see}} to new-format {{rootsee}}",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
