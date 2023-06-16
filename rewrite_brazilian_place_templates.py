#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn in ["place:Brazil/municipality", "place:municipality of Brazil"]:
      state = getparam(t, "state")
      trans = getparam(t, "2")
      blib.set_template_name(t, "place")
      rmparam(t, "state")
      t.add("2", "municipality")
      t.add("3", "s/%s" % state)
      t.add("4", "c/Brazil")
      if trans:
        t.add("t", trans)
    if tn in ["place:Brazil/state", "place:state of Brazil"]:
      region = getparam(t, "region")
      capital = getparam(t, "capital")
      trans = getparam(t, "2")
      blib.set_template_name(t, "place")
      rmparam(t, "region")
      rmparam(t, "capital")
      t.add("2", "state")
      t.add("3", "r/%s" % region)
      t.add("4", "c/Brazil")
      t.add("capital", capital)
      if trans:
        t.add("t", trans)
    if tn in ["place:Brazil/state capital", "place:state capital of Brazil"]:
      state = getparam(t, "state")
      trans = getparam(t, "2")
      blib.set_template_name(t, "place")
      rmparam(t, "state")
      t.add("2", "municipality/state capital")
      t.add("3", "s/%s" % state)
      t.add("4", "c/Brazil")
      if trans:
        t.add("t", trans)
    if tn in ["place:Brazil/capital", "place:capital of Brazil"]:
      trans = getparam(t, "2")
      blib.set_template_name(t, "place")
      t.add("2", "municipality/capital city")
      t.add("3", "c/Brazil")
      t.add("4", ";")
      t.add("5", "state capital")
      t.add("6", "s/Distrito Federal")
      t.add("7", "c/Brazil")
      if trans:
        t.add("t", trans)
    newt = str(t)
    if origt != newt:
      notes.append("replace {{%s}} with {{place}}" % tn)
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser("Rewrite Brazil-specific place templates to use {{place}}",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_refs=["Template:place:Brazil/capital", "Template:place:Brazil/state", "Template:place:Brazil/state capital",
      "Template:place:Brazil/municipality"], edit=True)
