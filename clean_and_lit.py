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
  notes = []

  for t in parsed.filter_templates():
    origt = unicode(t)
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

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Clean up use of dot= and .= in {{&lit}}, {{&oth}}, rename {{&oth}} to {{&lit}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in ["&lit", "&oth"]:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
