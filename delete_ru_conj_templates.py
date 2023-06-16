#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Delete ru-conj-* templates and documentation pages")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

msg("WARNING: Script no longer applies and would need fixing up")

types = ["1a", "2a", "2b", "3oa", "3a", "3b", "3c", "4a", "4b", "4c", "5a",
    "5b", "5c", "6a", "6b", "6c",
    "7a", "7b", "8a", "8b", "9a", "9b", "10a", "10c", "11a", "11b",
    "12a", "12b", "13b", "14a", "14b", "14c", "15a", "16a", "16b",
    u"irreg-бежать", u"irreg-спать", u"irreg-хотеть", u"irreg-дать",
    u"irreg-есть", u"irreg-сыпать", u"irreg-лгать", u"irreg-мочь",
    u"irreg-слать", u"irreg-идти", u"irreg-ехать", u"irreg-минуть",
    u"irreg-живописать-миновать", u"irreg-лечь", u"irreg-зиждиться",
    u"irreg-клясть", u"irreg-слыхать-видать", u"irreg-стелить-стлать",
    u"irreg-быть", u"irreg-ссать-сцать", u"irreg-чтить", u"irreg-шибить",
    u"irreg-плескать", u"irreg-реветь", u"irreg-внимать", u"irreg-внять",
    u"irreg-обязывать"]
for i, ty in blib.iter_items(types, start, end):
  template_page = pywikibot.Page(site, "Template:ru-conj-%s" % ty)
  if template_page.exists():
    template_page.delete("Replace with template ru-conj")
  template_doc_page = pywikibot.Page(site, "Template:ru-conj-%s/documentation" % ty)
  if template_doc_page.exists():
    template_doc_page.delete("Replace with template ru-conj")
