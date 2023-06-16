#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    param2 = getparam(t, "2")
    param3 = getparam(t, "3")
    if str(t.name) in ["ru-conj", "ru-conj-old"] and param2.startswith("8b"):
      if [x for x in t.params if str(x.value) == "or"]:
        errpagemsg("WARNING: Skipping multi-arg conjugation: %s" % str(t))
        continue
      if param2 in ["8b", "8b+p"]:
        t.add("2", getparam(t, "2").replace("8b", "8b/b"))
        notes.append("make past stress /b explicit in class 8b")
      elif param2 in ["8b/a", "8b/a+p"]:
        t.add("2", getparam(t, "2").replace("/a", ""))
        notes.append("make past stress /a default in class 8b")
      elif param2 not in ["8b/b", "8b/b+p"]:
        errpagemsg("WARNING: Unable to parse param2 %s" % param2)
    if str(t.name) in ["ru-conj", "ru-conj-old"] and param2.startswith("irreg"):
      if re.search(u"(да́?ть|бы́?ть|кля́?сть)(ся)?$", param3):
        if param2 == "irreg":
          if param3.startswith(u"вы́"):
            t.add("2", "irreg/a(1)")
            notes.append("make past stress /a(1) explicit in irreg verb")
          elif param3.endswith(u"ся"):
            t.add("2", "irreg/c''")
            notes.append("make past stress /c'' explicit in irreg verb")
          elif param3.endswith(u"дать") or param3.endswith(u"да́ть"):
            t.add("2", "irreg/c'")
            notes.append("make past stress /c' explicit in irreg verb")
          else:
            t.add("2", "irreg/c")
            notes.append("make past stress /c explicit in irreg verb")
        elif param2 == "irreg/a":
          t.add("2", "irreg")
          notes.append("make past stress /a default in irreg verb")
        elif not param2.startswith("irreg/"):
          errpagemsg("WARNING: Unable to parse param2 %s" % param2)

    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Fix up class-8 and irregular arguments to have class a as default past stress")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.cat_articles("Russian class 8b verbs", start, end):
  blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
for i, page in blib.cat_articles("Russian irregular verbs", start, end):
  blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
