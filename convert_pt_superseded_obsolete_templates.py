#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json, unicodedata

import blib
from blib import getparam, rmparam, getrmparam, tname, pname, msg, errandmsg, site

templates_to_rewrite = [
  ("pt-pre-1911", ("43", "11")),
  ("pt-archaic-hellenism", ("43", "11")),
  ("pt-archaic-latinism", ("43", "11")),
  ("pt-obsolete-hellenism", ("43", "11")),
  ("pt-obsolete-silent-letter-1911", ("43", "11")),
  ("pt-archaic-silent-letter-1911", ("43", "11")),
  ("pt-dated-differential-accent", ("71", "45")),
  ("pt-obsolete-differential-accent", ("71", "45")),
  ("pt-dated-secondary-stress", ("71", "73")),
  ("pt-obsolete-secondary-stress", ("71", "73")),
  ("pt-superseded-silent-letter-1990", ("43", "90")),
  ("pt-superseded-ü", ("90", "45")),
  ("pt-obsolete-ü", ("90", "45")),
  ("pt-superseded-paroxytone", ("90", "90")),
  ("pt-superseded-diacritic-Brazil", ("90", "0")),
  ("pt-obsolete-ôo", ("90", "0")),
  ("pt-superseded-ôo", ("90", "0")),
  ("pt-superseded-éia", ("90", "0")),
  ("pt-obsolete-éia", ("90", "0")),
  ("pt-archaic-sc", ("43", "45")),
  ("pt-obsolete-sc", ("43", "45")),
]

templates_to_rewrite_set = set(x for x, y in templates_to_rewrite)
templates_to_rewrite_set.add("pt-superseded-hyphen")

templates_to_rewrite_dict = dict(templates_to_rewrite)


def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    allow_dialect_param = False
    if tn == "pt-superseded-hyphen":
      allow_dialect_param = True
      dialect = getp("dialect")
      if dialect == "Brazil":
        br = "90"
        pt = "0"
      elif dialect == "Portugal":
        br = "0"
        pt = "90"
      else:
        br = "90"
        pt = "90"
    elif tn in templates_to_rewrite_dict:
      br, pt = templates_to_rewrite_dict[tn]
    else:
      continue

    must_continue = False
    for param in t.params:
      pn = pname(param)
      pv = str(param.value)
      if pn != "1" and pn != "lang" and not (allow_dialect_param and pn == "dialect"):
        pagemsg("WARNING: Unrecognized param: %s=%s" % (pn, pv))
        must_continue = True
        break
    if must_continue:
      continue

    param1 = getp("1")
    # Erase all params
    del t.params[:]
    t.add("1", param1)
    t.add("br", br)
    t.add("pt", pt)
    blib.set_template_name(t, "pt-pre-reform")
    pagemsg("Replace %s with %s" % (origt, str(t)))
    notes.append("convert %s to %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert old templates for superseded/obsolete Portuguese terms",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(
  args, start, end, process_text_on_page,
  default_refs=["Template:%s" % x for x in templates_to_rewrite_set], edit=True, stdin=True
)
