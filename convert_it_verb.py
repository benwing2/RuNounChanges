#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def split_with_footnotes(text):
  split_text = re.split(r"(\[.*?\])", text) + [""]
  retval = [""]
  for i in range(0, len(split_text), 2):
    split_part = split_text[i].split(",")
    retval[-1] += split_part[0]
    retval.extend(split_part[1:])
    retval[-1] += split_text[i + 1]
  return retval

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
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    if tn in ["it-verb"]:
      pagemsg("Saw %s" % str(t))
      if not getp("1"):
        continue
      parts = []
      aux = getp("aux") or "avere"
      split_aux_with_footnotes = split_with_footnotes(aux)
      split_aux_with_footnotes = [re.sub("^avere", "a", x) for x in split_aux_with_footnotes]
      split_aux_with_footnotes = [re.sub("^essere", "e", x) for x in split_aux_with_footnotes]
      parts.append(":".join(split_aux_with_footnotes) + "/")
      parts.append(":".join(split_with_footnotes(getp("1"))))
      arg2 = getp("2")
      arg3 = getp("3")
      if arg2 or arg3:
        parts.append("," + ":".join(split_with_footnotes(arg2)))
      if arg3:
        parts.append("," + ":".join(split_with_footnotes(arg3)))
      irregparams = ["imperf", "fut", "sub", "impsub", "imp"]
      for irregparam in irregparams:
        arg = getp(irregparam)
        if arg:
          parts.append("." + irregparam + ":" + ":".join(split_with_footnotes(arg)))
      if getp("impers"):
        parts.append(".only3s")
      if getp("only3sp"):
        parts.append(".only3sp")
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "aux", "impers", "only3sp"] and pn not in irregparams:
          pagemsg("WARNING: Unrecognized param %s=%s" % (pn, str(param.value)))
          must_continue = True
          break
      if must_continue:
        continue
      del t.params[:]
      t.add("1", "".join(parts))
      notes.append("convert {{it-verb}} params to new form")
    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Remove redundant respellings in {{it-IPA}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:it-verb"])
