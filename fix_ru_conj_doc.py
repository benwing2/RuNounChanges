#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Remove adj= and shto= from ru-ux.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("WARNING: Script no longer applies and would need fixing up")
  return

  pagemsg("Processing")
  return "#REDIRECT [[Module:ru-verb/documentation]]", "redirect to [[Module:ru-verb/documentation]]"

parser = blib.create_argparser("Redirect ru-conj-* documentation pages")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

types = ["7a", "7b", "8a", "8b", "9a", "9b", "10a", "10c", "11a", "11b",
    "12a", "12b", "13b", "14a", "14b", "14c", "15a", "16a", "16b",
    u"irreg-бежать", u"irreg-спать", u"irreg-хотеть", u"irreg-дать",
    u"irreg-есть", u"irreg-сыпать", u"irreg-лгать", u"irreg-мочь",
    u"irreg-слать", u"irreg-идти", u"irreg-ехать", u"irreg-минуть",
    u"irreg-живописать-миновать", u"irreg-лечь", u"irreg-зиждиться",
    u"irreg-клясть", u"irreg-слыхать-видать", u"irreg-стелить-стлать",
    u"irreg-быть", u"irreg-ссать-сцать", u"irreg-чтить", u"irreg-ошибиться",
    u"irreg-плескать", u"irreg-внимать", u"irreg-обязывать"]
for i, ty in blib.iter_items(types, start, end):
  template = "Template:ru-conj-%s/documentation" % ty
  blib.do_edit(pywikibot.Page(site, template), i, process_page, save=args.save,
    verbose=args.verbose, diff=args.diff)
