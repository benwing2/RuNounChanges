#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

AA = u"\u093e"
M = u"\u0901"
IND_AA = u"आ"

def hi_adj_is_indeclinable(t, pagetitle):
  if tname(t) == "hi-adj":
    pagename = blib.remove_links(getparam(t, "head") or pagetitle)
    # If the lemma doesn't end with any of the declinable suffixes, it's
    # definitely indeclinable. Some indeclinable adjectives end with these
    # same suffixes, but we have no way to know that these are indeclinable,
    # so assume declinable.
    return not (pagename.endswith(AA) or pagename.endswith(IND_AA) or
        pagename.endswith(AA + M))
  return False

def process_page(page, index, parsed):
  global args
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  saw_potentially_declinable_adjective = False
  saw_hi_adj_auto = False
  headt = None
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = unicode(t)
    if tn == "hi-adj":
      headt = t
      if hi_adj_is_indeclinable(t, pagetitle):
        if not getparam(t, "ind"):
          t.add("ind", "1")
          notes.append("add ind=1 to {{%s}}" % tn)
      else:
        saw_potentially_declinable_adjective = True
        pagemsg("Skipping potentially declinable adjective: %s" % unicode(t))
      if unicode(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
    elif tn == "hi-adj-auto":
      saw_hi_adj_auto = True
  if saw_potentially_declinable_adjective and not saw_hi_adj_auto:
    pagemsg("WARNING: Potentially declinable adjective and no declension template: %s" % unicode(headt))

  return unicode(parsed), notes

parser = blib.create_argparser("Add ind=1 to indeclinable adjectives",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_cats=["Hindi adjectives"])
