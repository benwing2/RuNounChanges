#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

from form_of_templates import (
  language_specific_alt_form_of_templates,
  alt_form_of_templates,
  language_specific_form_of_templates,
  form_of_templates
)

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in deftempboiler_templates:
      cap = getparam(t, "cap")
      if cap:
        if cap == tn[0]:
          t.add("nocap", "1")
          notes.append("convert cap=%s to nocap=1 in {{%s}}" % (cap, tn))
        else:
          notes.append("remove unnecessary cap=%s in {{%s}}" % (cap, tn))
        rmparam(t, "cap")
      if t.has("dot") and not getparam(t, "dot"):
        rmparam(t, "dot")
        t.add("nodot", "1")
        notes.append("convert empty dot= to nodot=1 in {{%s}}" % tn)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert cap= to nocap= and empty dot= to nodot= in templates based on {{deftempboiler}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in ["egy-alt"]:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
