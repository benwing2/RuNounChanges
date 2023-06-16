#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Fix up noun forms, using {{ru-noun form}} instead of {{head|ru|noun form}}

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def getrmparam(t, param):
  value = getparam(t, param)
  rmparam(t, param)
  return value

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = str(page.text)
  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    if str(t.name) == "head" and getparam(t, "1") == "ru" and getparam(t, "2") == "noun form":
      if getparam(t, "3"):
        pagemsg("WARNING: Found param 3 in {{head|ru|noun form}}: %s" %
            str(t))
        return
      rmparam(t, "1")
      rmparam(t, "2")
      head = getrmparam(t, "head")
      head2 = getrmparam(t, "head2")
      tr = getrmparam(t, "tr")
      tr2 = getrmparam(t, "tr2")
      g = getrmparam(t, "g")
      g2 = getrmparam(t, "g2")
      g3 = getrmparam(t, "g3")
      if len(t.params) > 0:
        pagemsg("WARNING: Extra params in noun form template: %s" %
            str(t))
        return
      t.name = "ru-noun form"
      if head or g:
        t.add("1", head)
      if head2:
        t.add("head2", head2)
      if g:
        t.add("2", g)
      if g2:
        t.add("g2", g2)
      if g3:
        t.add("g3", g3)
      if tr:
        t.add("tr", tr)
      if tr2:
        t.add("tr2", tr2)
      newt = str(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))
        notes.append("convert {{head|ru|noun form}} to {{ru-noun form}}")
    elif str(t.name) == "ru-noun form":
      if getparam(t, "head") and getparam(t, "1"):
        pagemsg("WARNING: ru-noun form has both params 1= and head=: %s" %
            str(t))
        return
      if getparam(t, "g") and getparam(t, "2"):
        pagemsg("WARNING: ru-noun form has both params 2= and g=: %s" %
            str(t))
        return
      head = getrmparam(t, "1") or getrmparam(t, "head")
      head2 = getrmparam(t, "head2")
      tr = getrmparam(t, "tr")
      tr2 = getrmparam(t, "tr2")
      g = getrmparam(t, "2") or getrmparam(t, "g")
      g2 = getrmparam(t, "g2")
      g3 = getrmparam(t, "g3")
      if len(t.params) > 0:
        pagemsg("WARNING: Extra params in noun form template: %s" %
            str(t))
        return
      if head or g:
        t.add("1", head)
      if head2:
        t.add("head2", head2)
      if g:
        t.add("2", g)
      if g2:
        t.add("g2", g2)
      if g3:
        t.add("g3", g3)
      if tr:
        t.add("tr", tr)
      if tr2:
        t.add("tr2", tr2)
      newt = str(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))
        notes.append("canonicalize ru-noun form")

  return str(parsed), notes

parser = blib.create_argparser("Canonicalize {{head|ru|noun form}} and {{ru-noun form}}",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian noun forms"])
