#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not re.search(r"\{\{pt-noun form of", text):
    return

  pagemsg("Processing")

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)

    def feminize_noun(noun):
      if noun.endswith("ão"):
        return noun[:-2] + "ona"
      if noun.endswith("dor"):
        return noun + "a"
      if noun.endswith("o"):
        return noun[:-1] + "a"
      pagemsg("WARNING: Don't know how to compute female equivalent of %s: %s" % (noun, str(t)))
      return None

    def singularize_feminine_noun(noun):
      if noun.endswith("as"):
        return noun[:-1]
      pagemsg("WARNING: Don't know how to compute singular equivalent of feminine noun %s: %s" % (noun, str(t)))
      return None

    if tn == "pt-noun form of":
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "4", "t", "nocap", "nodot"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pn, str(param.value, origt)))
          return

      lemma = blib.remove_links(getparam(t, "1"))
      gender = getparam(t, "2")
      number = getparam(t, "3")
      dimaug = getparam(t, "4")
      gloss = getparam(t, "t")
      if dimaug:
        pagemsg("WARNING: Not sure what to do with 4=%s: %s" % (dimaug, origt))
        return
      if gender in ["m", "mf", "m-f", "onlym", "onlyf"]:
        if number == "sg":
          pagemsg("WARNING: Not sure what to do with 2=%s 3=s: %s" % (gender, origt))
          return
        if number != "pl":
          pagemsg("WARNING: Unrecognized number 3=%s: %s" % (number, origt))
          return
        newname = "plural of"
      elif gender != "f":
        pagemsg("WARNING: Unrecognized gender 2=%s: %s" % (gender, origt))
        return
      else:
        if number == "sg":
          newname = "female equivalent of"
        elif number != "pl":
          pagemsg("WARNING: Unrecognized number 3=%s: %s" % (number, origt))
          return
        else:
          lemma = singularize_feminine_noun(pagetitle)
          if not lemma:
            return
          newname = "plural of"
      del t.params[:]
      blib.set_template_name(t, newname)
      t.add("1", "pt")
      t.add("2", lemma)
      if gloss:
        t.add("3", "")
        t.add("4", gloss)
      notes.append("replace {{pt-noun form of}} with {{%s|pt}}" % newname)
    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Replace {{pt-noun form of}} with appropriate non-language specific templates",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_refs=[
  "Template:pt-noun form of"],
  edit=True, stdin=True)
