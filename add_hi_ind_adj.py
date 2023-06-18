#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

AA = u"\u093e"
M = u"\u0901"
N = u"\u0902"
IND_AA = u"आ"

def hi_adj_is_indeclinable(t, pagetitle):
  if tname(t) == "hi-adj":
    pagename = blib.remove_links(getparam(t, "head") or pagetitle)
    # If the lemma doesn't end with any of the declinable suffixes, it's
    # definitely indeclinable. Some indeclinable adjectives end with these
    # same suffixes, but we have no way to know that these are indeclinable,
    # so assume declinable.
    return not (pagename.endswith(AA) or pagename.endswith(IND_AA) or
        pagename.endswith(AA + M) or pagename.endswith(IND_AA + M) or
        pagename.endswith(AA + N) or pagename.endswith(IND_AA + N))
  return False

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  saw_potentially_declinable_adjective = False
  saw_hi_adecl = False
  saw_hi_adj_with_translit = False
  headt = None

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn == "hi-adj":
      headt = t
      if getparam(t, "tr") or getparam(t, "tr2") or getparam(t, "tr3"):
        saw_hi_adj_with_translit = True
      if hi_adj_is_indeclinable(t, pagetitle):
        if not getparam(t, "ind"):
          t.add("ind", "1")
          notes.append("add ind=1 to {{%s}}" % tn)
      else:
        saw_potentially_declinable_adjective = True
        pagemsg("Skipping potentially declinable adjective: %s" % str(t))
      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))
    elif tn == "hi-adecl":
      saw_hi_adecl = True
  if saw_potentially_declinable_adjective and not saw_hi_adecl:
    pagemsg("WARNING: Potentially declinable adjective and no declension template: %s" % str(headt))
  if saw_potentially_declinable_adjective and saw_hi_adecl and saw_hi_adj_with_translit:
    pagemsg("WARNING: Declinable adjective with manual translit: %s" % str(headt))

  return str(parsed), notes

parser = blib.create_argparser("Add ind=1 to indeclinable adjectives",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True, stdin=True,
    default_cats=["Hindi adjectives"])
