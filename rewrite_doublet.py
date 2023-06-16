#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

# WARNING: Not idempotent.

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  text = str(page.text)

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  if blib.page_should_be_ignored(pagetitle):
    pagemsg("WARNING: Page should be ignored")
    return None, None

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)

    if tn == "doublet":
      params = []
      for param in t.params:
        pname = str(param.name).strip()
        pval = str(param.value).strip()
        showkey = param.showkey
        if not pval:
          continue
        if pname == "3":
          pname = "alt1"
          showkey = True
        elif pname == "4":
          pname = "t1"
          showkey = True
        elif pname in ["t", "gloss", "tr", "ts", "pos", "lit", "alt", "sc",
            "id", "g"]:
          pname = pname + "1"
        elif pname in ["1", "2", "notext", "nocap", "nocat"]:
          pass
        else:
          pagemsg("WARNING: Unrecognized param %s=%s in %s, skipping" %
              (pname, pval, origt))
          break
        params.append((pname, pval, showkey))
      else: # No break
        # Erase all params.
        del t.params[:]
        # Put back new params.
        for pname, pval, showkey in params:
          t.add(pname, pval, showkey=showkey, preserve_spacing=False)
        if origt != str(t):
          pagemsg("Replaced %s with %s" % (origt, str(t)))
          notes.append("restructure {{doublet}} for new syntax")

  return str(parsed), notes

parser = blib.create_argparser("Rewrite 'doublet' to use multiple-term syntax",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:doublet"])
