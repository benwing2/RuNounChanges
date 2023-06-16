#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Find and fix deprecated usages of {{prefixusex}} and {{suffixusex}}: Either use of the lang= param,
# or a prefix as a term in {{prefixusex}} or a suffix as a term in {{suffixusex}}. We only fix lang=;
# the other case is rare and we fix it manually.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = str(page.text)
  parsed = blib.parse(page)
  notes = []

  for t in parsed.filter_templates():
    origt = str(t)
    if tname(t) == "prefixusex":
      if getparam(t, "1").endswith("-") or getparam(t, "2").endswith("-"):
        pagemsg("WARNING: Has prefix as term: %s" % origt)
    if tname(t) == "suffixusex":
      if getparam(t, "1").startswith("-") or getparam(t, "2").startswith("-"):
        pagemsg("WARNING: Has suffix as term: %s" % origt)
    if tname(t) in ["prefixusex", "suffixusex"]:
      if getparam(t, "lang"):
        pagemsg("WARNING: Uses lang= param: %s" % origt)
        lang = getparam(t, "lang")
        term1 = getparam(t, "1")
        term2 = getparam(t, "2")
        altsuf = getparam(t, "altsuf")
        altpref = getparam(t, "altpref")
        t1 = getparam(t, "t1") or getparam(t, "gloss1")
        t2 = getparam(t, "t2") or getparam(t, "gloss2")
        alt1 = getparam(t, "alt1")
        alt2 = getparam(t, "alt2")
        pos1 = getparam(t, "pos1")
        pos2 = getparam(t, "pos2")
        # Fetch remaining non-numbered params.
        non_numbered_params = []
        for param in t.params:
          pname = str(param.name)
          if not re.search(r"^[0-9]+$", pname) and pname not in ["lang", "t1", "gloss1", "t2", "gloss2",
              "alt1", "alt2", "pos1", "pos2", "altpref", "altsuf"]:
            non_numbered_params.append((pname, param.value))
        # Erase all params.
        del t.params[:]
        # Put back params in proper order, then the remaining non-numbered params.
        t.add("1", lang)
        if altpref:
          t.add("altpref", altpref)
        if term1:
          t.add("2", term1)
        if alt1:
          t.add("alt1", alt1)
        if pos1:
          t.add("pos1", pos1)
        if t1:
          t.add("t1", t1)
        if altsuf:
          t.add("altsuf", altsuf)
        if term2:
          t.add("3", term2)
        if alt2:
          t.add("alt2", alt2)
        if pos2:
          t.add("pos2", pos2)
        if t2:
          t.add("t2", t2)
        for name, value in non_numbered_params:
          t.add(name, value)
        notes.append("Move lang= to 1= in prefixusex/suffixusex")
        if getparam(t, "inline"):
          rmparam(t, "inline")
          notes.append("Remove inline= in prefixusex/suffixusex")
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes


parser = blib.create_argparser('Find deprecated usages of {{prefixusex}} and {{suffixusex}} and fix some of them',
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:prefixusex", "Template:suffixusex"])
