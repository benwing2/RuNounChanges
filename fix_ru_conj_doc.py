#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Remove adj= and shto= from ru-ux.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  new_text = "#REDIRECT [[Module:ru-verb/documentation]]"
  comment = "redirect to [[Module:ru-verb/documentation]]"
  if save:
    pagemsg("Saving with comment = %s" % comment)
    page.text = new_text
    page.save(comment=comment)
  else:
    pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Redirect ru-conj-* documentation pages")
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
  process_page(i, pywikibot.Page(site, template), args.save, args.verbose)
