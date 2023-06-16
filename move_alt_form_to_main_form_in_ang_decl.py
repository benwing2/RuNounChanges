#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn.startswith("ang-decl-"):
      origt = str(t)
      alt1 = getparam(t, "alt1")
      if alt1:
        t.add("1", alt1, before="alt1")
        rmparam(t, "alt1")
      alt2 = getparam(t, "alt2")
      if alt2:
        t.add("2", alt2, before="alt2")
        rmparam(t, "alt2")
      altnomsg = getparam(t, "altnomsg")
      if altnomsg:
        t.add("nomsg", altnomsg, before="altnomsg")
        rmparam(t, "altnomsg")
      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("move alt param to main param in {{ang-decl-*}}")

  return str(parsed), notes

parser = blib.create_argparser(u"Move alt form to main form in {{ang-decl-*}}",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
