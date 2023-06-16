#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Use past_adv_part_short=- instead of past_adv_part_short=

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    if (str(t.name) in ["ru-conj", "ru-conj-old"] and
        getparam(t, "2") in ["7a", "7b"]):
      if [x for x in t.params if str(x.value) == "or"]:
        pagemsg("WARNING: Skipping multi-arg conjugation: %s" % str(t))
        continue
      if t.has("past_adv_part_short") and getparam(t, "past_adv_part_short") == "":
        notes.append("set past_adv_part_short=-")
        origt = str(t)
        t.add("past_adv_part_short", "-")
        pagemsg("Replacing %s with %s" % (origt, str(t)))
      if t.has("past_actv_part") and getparam(t, "past_actv_part") == "":
        notes.append("set past_actv_part=-")
        origt = str(t)
        t.add("past_actv_part", "-")
        pagemsg("Replacing %s with %s" % (origt, str(t)))

  if new_text != text:
    return new_text, notes

  if not notes:
    pagemsg("WARNING: No changes")

parser = blib.create_argparser("Fix past_adv_part_short to use dash instead of blank",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:tracking/ru-verb/different-conj"])
