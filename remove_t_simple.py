#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn == "t-simple":
      interwiki = getparam(t, "interwiki")
      rmparam(t, "interwiki")
      rmparam(t, "langname")
      g = getparam(t, "g")
      rmparam(t, "g")
      if g:
        t.add("3", g)
      if interwiki:
        tempname = "t+"
      else:
        tempname = "t"
      blib.set_template_name(t, tempname)
      notes.append("convert {{t-simple}} to {{%s}}" % tempname)

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Convert {{t-simple}} to {{t}} or {{t+}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
