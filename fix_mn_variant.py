#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn == "mn-variant":
      origt = str(t)
      m = getp("m")
      if m:
        t.add("1", m, before="m")
        t.add("2", m, before="m")
      c = getp("c")
      if c:
        t.add("3", c, before="c")
      rmparam(t, "m")
      rmparam(t, "c")
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("Convert m=/c= in {{mn-variant}} to numbered params")

  return str(parsed), notes

parser = blib.create_argparser("Convert m=/c= in {{mn-variant}} to numbered params",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:mn-variant"])
