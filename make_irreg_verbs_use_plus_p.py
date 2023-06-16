#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, copy

import blib
from blib import getparam, rmparam, tname, msg, errmsg, site

def process_page(page, index, parsed):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    if tname(t) in ["ru-conj", "ru-conj-old"]:
      if [x for x in t.params if str(x.value) == "or"]:
        errpagemsg("WARNING: Skipping multi-arg conjugation: %s" % str(t))
        continue
      param2 = getparam(t, "2")
      if "+p" in param2:
        continue
      ppp = getparam(t, "ppp") or getparam(t, "past_pasv_part")
      if not ppp or ppp == "-":
        continue
      ppp2 = getparam(t, "ppp2") or getparam(t, "past_pasv_part2")
      rmparam(t, "ppp")
      rmparam(t, "past_pasv_part")
      rmparam(t, "ppp2")
      rmparam(t, "past_pasv_part2")
      t.add("2", param2 + "+p")
      if tname(t) == "ru-conj":
        tempcall = re.sub(r"^\{\{ru-conj", "{{ru-generate-verb-forms", str(t))
      else:
        tempcall = re.sub(r"^\{\{ru-conj-old", "{{ru-generate-verb-forms|old=1", str(t))
      result = expand_text(tempcall)
      if not result:
        errpagemsg("WARNING: Error expanding template %s" % tempcall)
        continue
      forms = blib.split_generate_args(result)
      pppform = forms.get("past_pasv_part", "")
      if "," in pppform:
        auto_ppp, auto_ppp2 = pppform.split(",")
        wrong = False
        if ppp != auto_ppp:
          errpagemsg("WARNING: ppp %s != auto_ppp %s" % (ppp, auto_ppp))
          wrong = True
        if ppp2 != auto_ppp2:
          errpagemsg("WARNING: ppp2 %s != auto_ppp2 %s" % (ppp2, auto_ppp2))
          wrong = True
        if wrong:
          continue
      else:
        if ppp != pppform:
          errpagemsg("WARNING: ppp %s != auto_ppp %s" % (ppp, pppform))
          continue
    newt = str(t)
    if origt != newt:
      notes.append("Replaced manual ppp= with irreg verb with +p")
      pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Make irregular verbs use +p instead of manual ppp=")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian irregular verbs"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
