#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  text = str(page.text)
  if pagetitle.startswith("Module:"):
    return

  pagemsg("Processing")
  notes = []

  # WARNING: Not idempotent.

  to_add_period = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "etydate" and not getparam(t, "nodot"):
      to_add_period.append(str(t))

  for curr_template in to_add_period:
    repl_template = curr_template + "."
    newtext, did_replace = blib.replace_in_text(text, curr_template, repl_template, pagemsg)
    if did_replace:
      newnewtext = re.sub(re.escape(curr_template) + r"\.([.,])", curr_template + r"\1", newtext)
      if newnewtext != newtext:
        m = re.search("^.*" + re.escape(curr_template) + "[.,].*$", text, re.M)
        if m:
          origline = m.group(0)
        else:
          origline = "[WARNING: CAN'T LOCATE?]"
        pagemsg("WARNING: {{etydate}} template already contains period or comma after it; original line follows: %s" %
                origline)
        newtext = newnewtext
      if newtext != text:
        notes.append("add period to {{etydate}} template (formerly automatically added)")
        text = newtext

  return text, notes

parser = blib.create_argparser("Add period to {{etydate}} templates where it was formerly automatically added",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, default_refs=["Template:etydate"], edit=True)