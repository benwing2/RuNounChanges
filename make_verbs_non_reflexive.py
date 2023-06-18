#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, copy

import blib
from blib import getparam, rmparam, tname, msg, errmsg, site

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
    if tname(t) in ["ru-conj", "ru-conj-old", "User:Benwing2/ru-conj",
        "User:Benwing2/ru-conj-old"]:
      t.add("1", getparam(t, "1").replace("-refl", ""))
    elif tname(t) == "temp" and getparam(t, "1") == "ru-conj":
      t.add("2", getparam(t, "2").replace("-refl", ""))
    newt = str(t)
    if origt != newt:
      notes.append("remove -refl from verb type")
      pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Fix up verb conjugations to not specify -refl")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_edit(pywikibot.Page(site, "User:Benwing2/test-ru-verb"), 1,
  process_page, save=args.save, verbose=args.verbose)
blib.do_edit(pywikibot.Page(site, "User:Benwing2/test-ru-verb-2"), 2,
  process_page, save=args.save, verbose=args.verbose)
for ref in ["Template:ru-conj-old"]:
  msg("Processing references to: %s" % ref)
  for i, page in blib.references(ref, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
blib.do_edit(pywikibot.Page(site, "Module:ru-verb/documentation"), 1,
  process_page, save=args.save, verbose=args.verbose)
for category in ["Russian verbs"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
