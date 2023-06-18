#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname

from collections import defaultdict

coiner_count = defaultdict(set)

def count_coiners(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  if "coin" not in text:
    return

  pagemsg("Processing")

  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["coin", "coinage"]:
      lang = getparam(t, "1")
      coiner = getparam(t, "2")
      coiner_count[(lang, coiner)].add(pagename)
      pagemsg("Count for (%s, %s) is now %s" % (lang, coiner, len(coiner_count[(lang, coiner)])))

def add_remove_nobycat(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  if "coin" not in text:
    return

  pagemsg("Processing")

  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn in ["coin", "coinage"]:
      lang = getparam(t, "1")
      coiner = getparam(t, "2")
      if len(coiner_count[(lang, coiner)]) == 1:
        if not getparam(t, "nobycat") and not getparam(t, "nocat"):
          t.add("nobycat", "1")
          notes.append("add nobycat=1 to {{coinage|%s|%s}}" % (lang, coiner))
      elif len(coiner_count[(lang, coiner)]) > 1:
        if getparam(t, "nocat"):
          pagemsg("WARNING: Lang %s, coiner %s has %s total words coined but has nocat=1: %s" % (
            lang, coiner, len(coiner_count[(lang, coiner)]), str(t)))
        elif getparam(t, "nobycat"):
          rmparam(t, "nobycat")
          notes.append("remove nobycat= from {{coinage|%s|%s}}" % (lang, coiner))
    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Add or remove nobycat= as necessary to/from {{coinage}}", include_pagefile=True,
    include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, count_coiners, edit=True, stdin=True)
blib.do_pagefile_cats_refs(args, start, end, add_remove_nobycat, edit=True, stdin=True)
