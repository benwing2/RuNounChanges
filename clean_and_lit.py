#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["&lit", "&oth"]:
      if t.has("dot"):
          if not getparam(t, "dot"):
            rmparam(t, "dot")
            t.add("nodot", "1")
            notes.append("convert empty dot= to nodot=1 in {{%s}}" % tn)
          if t.has("."):
            rmparam(t, ".")
            notes.append("remove .= in {{%s}} that's overridden by dot=" % tn)
      elif t.has("."):
        dot = getparam(t, ".")
        if not dot:
          rmparam(t, ".")
          t.add("nodot", "1")
          notes.append("convert empty .= to nodot=1 in {{%s}}" % tn)
        else:
          t.add("dot", dot, before=".")
          rmparam(t, ".")
          notes.append("convert .= to dot= in {{%s}}" % tn)
      if tn == "&oth":
        blib.set_template_name(t, "&lit")
        notes.append("convert {{&oth}} to {{&lit}}")

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Clean up use of dot= and .= in {{&lit}}, {{&oth}}, rename {{&oth}} to {{&lit}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:&lit", "Template:&oth"])
