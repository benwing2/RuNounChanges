#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Remove unnecessary fr-adj parameters.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  text = str(page.text)

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    name = str(t.name)
    if str(t.name) == "fr-adj":
      g = getparam(t, "1")
      if g and g != "mf":
        pagemsg("WARNING: Strange value 1=%s, removing: %s" % (g, str(t)))
        rmparam(t, "1")
        notes.append("remove bogus 1=%s" % g)
        g = None
      inv = getparam(t, "inv")
      if inv:
        if inv not in ["y", "yes", "1"]:
          pagemsg("WARNING: Strange value inv=%s: %s" % (inv, str(t)))
        if (getparam(t, "1") or getparam(t, "f") or
            getparam(t, "mp") or getparam(t, "fp") or getparam(t, "p")):
          pagemsg("WARNING: Found extraneous params with inv=: %s" %
              str(t))
        continue
      if (getparam(t, "f2") or getparam(t, "mp2") or getparam(t, "fp2")
          or getparam(t, "p2")):
        pagemsg("Skipping multiple feminines or plurals: %s" % str(t))
        continue
      expected_mp = (pagetitle if re.search("[sx]$", pagetitle)
          else re.sub("al$", "aux", pagetitle) if pagetitle.endswith("al")
          else pagetitle + "s")
      if getparam(t, "mp") == expected_mp:
        rmparam(t, "mp")
        notes.append("remove redundant mp=")
      expected_fem = (pagetitle if pagetitle.endswith("e")
          else pagetitle + "ne" if pagetitle.endswith("en")
          else re.sub("er$", "ère", pagetitle) if pagetitle.endswith("er")
          else pagetitle + "le" if pagetitle.endswith("el")
          else pagetitle + "ne" if pagetitle.endswith("on")
          else pagetitle + "te" if pagetitle.endswith("et")
          else pagetitle + "e" if pagetitle.endswith("ieur")
          else re.sub("teur$", "trice", pagetitle) if pagetitle.endswith("teur")
          else re.sub("eur$", "euse", pagetitle) if pagetitle.endswith("eur")
          else re.sub("eux$", "euse", pagetitle) if pagetitle.endswith("eux")
          else re.sub("if$", "ive", pagetitle) if pagetitle.endswith("if")
          else re.sub("c$", "que", pagetitle) if pagetitle.endswith("c")
          else pagetitle + "e")
      if re.search("(el|on|et|[^i]eur|eux|if|c)$", pagetitle) and not getparam(t, "f") and g != "mf":
        pagemsg("WARNING: Found suffix -el/-on/-et/-[^i]eur/-eux/-if/-c and no f= or 1=mf: %s" % str(t))
      if getparam(t, "f") == expected_fem:
        rmparam(t, "f")
        notes.append("remove redundant f=")
      fem = getparam(t, "f") or expected_fem
      if not fem.endswith("e"):
        if not getparam(t, "fp"):
          pagemsg("WARNING: Found f=%s not ending with -e and no fp=: %s" %
              (fem, str(t)))
        continue
      expected_fp = fem + "s"
      if getparam(t, "fp") == expected_fp:
        rmparam(t, "fp")
        notes.append("remove redundant fp=")
      if getparam(t, "fp") and not getparam(t, "f"):
        pagemsg("WARNING: Found fp=%s and no f=: %s" % (getparam(t, "fp"),
          str(t)))
        continue
      if getparam(t, "fp") == fem:
        pagemsg("WARNING: Found fp=%s same as fem=%s: %s" % (getparam(t, "fp"),
          fem, str(t)))
        continue
      if pagetitle.endswith("e") and not getparam(t, "f") and not getparam(t, "fp"):
        if g == "mf":
          rmparam(t, "1")
          notes.append("remove redundant 1=mf")
        g = "mf"
      if g == "mf":
        f = getparam(t, "f")
        if f:
          pagemsg("WARNING: Found f=%s and 1=mf: %s" % (f, str(t)))
        mp = getparam(t, "mp")
        if mp:
          pagemsg("WARNING: Found mp=%s and 1=mf: %s" % (mp, str(t)))
        fp = getparam(t, "fp")
        if fp:
          pagemsg("WARNING: Found fp=%s and 1=mf: %s" % (fp, str(t)))
        if f or mp or fp:
          continue
        expected_p = (pagetitle if re.search("[sx]$", pagetitle)
            else re.sub("al$", "aux", pagetitle) if pagetitle.endswith("al")
            else pagetitle + "s")
        if getparam(t, "p") == expected_p:
          rmparam(t, "p")
          notes.append("remove redundant p=")
      elif getparam(t, "p"):
        pagemsg("WARNING: Found unexpected p=%s: %s" % (getparam(t, "p"),
          str(t)))
      if not re.search("[ -]", pagetitle) and (getparam(t, "f") or
          getparam(t, "mp") or getparam(t, "fp") or getparam(t, "p")):
        pagemsg("Found remaining explicit feminine or plural in single-word base form: %s"
            % str(t))
    newt = str(t)
    if origt != newt:
      pagemsg("Replacing %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser("Remove extraneous params from {{fr-adj}}",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["French adjectives"])
