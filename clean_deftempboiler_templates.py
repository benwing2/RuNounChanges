#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

deftempboiler_templates = ["abbreviation of", "acronym of",
  "archaic form of", "clipping of", "contraction of",
  "dated form of", "dated spelling of", "deliberate misspelling of",
  "euphemistic form of", "euphemistic spelling of",
  "former name of", "informal form of", "informal spelling of",
  "initialism of", "misromanization of", "misspelling of",
  "nonstandard form of", "nonstandard spelling of", "obsolete form of",
  "official form of", "rare form of", "rare spelling of", "short for",
  "standard form of", "standard spelling of", "superseded spelling of",
  "uncommon form of", "uncommon spelling of"]

manual_templates = ["eye dialect of", "ja-form of", "jyutping reading of",
    "polytonic form of", "pronunciation spelling of", "spelling of"]

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = unicode(t)
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

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Convert cap= to nocap= and empty dot= to nodot= in templates based on {{deftempboiler}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in deftempboiler_templates:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
