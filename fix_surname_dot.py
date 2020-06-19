#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  if pagetitle.startswith("Module:"):
    return
  notes = []

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn == "surname":
      if t.has("nodot"):
        nodot = getparam(t, "nodot")
        if nodot == "2":
          pagemsg("nodot=2 means period, removing nodot= and dot=: %s" % unicode(t))
          rmparam(t, "nodot")
          rmparam(t, "dot")
          notes.append("remove nodot=2 and overridden dot= in {{%s}}" % tn)
        elif nodot != "1":
          pagemsg("nodot=%s means nothing, removing it: %s" % (nodot, unicode(t)))
          rmparam(t, "nodot")
          notes.append("remove effectless nodot=%s in {{%s}}" % (nodot, tn))
      if t.has("dot") and (not getparam(t, "dot") or getparam(t, "dot") == "<nowiki/>"):
        pagemsg("WARNING: empty dot= in {{surname}} template: %s" % unicode(t))
        rmparam(t, "dot")
        t.add("nodot", "1")
        notes.append("convert empty dot= to nodot=1 in {{%s}}" % tn)
    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Correct use of dot= and nodot= in {{surname}}",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, default_refs=["Template:surname"], edit=True)
