#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

lect_mappings = {
  "Min Bei": "Northern Min",
  "Min Dong": "Eastern Min",
  "Min Zhong": "Central Min",
  "Puxian": "Puxian Min",
}
# Puxian not here because the replacement contains the original value
lect_replacements = [
  ("Min Bei", "Northern Min"),
  ("Min Dong", "Eastern Min"),
  ("Min Zhong", "Central Min"),
]

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    if tn in blib.label_templates and getp("1") == "zh":
      for i in range(2, 30):
        label = getp(str(i))
        newlabel = lect_mappings.get(label, label)
        for k, v in lect_replacements:
          newlabel = newlabel.replace(k, v)
        # The following is OK in labels but not elsewhere.
        newlabel = newlabel.replace("Min Nan", "Southern Min")
        if newlabel != label:
          t.add(str(i), newlabel)
          notes.append("rename Chinese lect '%s' to '%s' in {{%s}}" % (label, newlabel, tn))
    if tn in blib.qualifier_templates:
      for i in range(1, 30):
        qual = getp(str(i))
        newqual = lect_mappings.get(qual, qual)
        for k, v in lect_replacements:
          newqual = newqual.replace(k, v)
        if newqual != qual:
          t.add(str(i), newqual)
          notes.append("rename Chinese lect '%s' to '%s' in {{%s}}" % (qual, newqual, tn))
    if tn == "zh-forms":
      alt = getp("alt")
      newalt = alt
      for k, v in lect_replacements:
        newalt = newalt.replace(k, v)
      if newalt != alt:
        t.add("alt", newalt)
        notes.append("rename Chinese lect '%s' to '%s' in {{%s}}" % (alt, newalt, tn))
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert Chinese lect names to English-style names",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
