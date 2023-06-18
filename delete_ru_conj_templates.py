#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser("Delete ru-conj-* templates and documentation pages")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

msg("WARNING: Script no longer applies and would need fixing up")

types = ["1a", "2a", "2b", "3oa", "3a", "3b", "3c", "4a", "4b", "4c", "5a",
    "5b", "5c", "6a", "6b", "6c",
    "7a", "7b", "8a", "8b", "9a", "9b", "10a", "10c", "11a", "11b",
    "12a", "12b", "13b", "14a", "14b", "14c", "15a", "16a", "16b",
    "irreg-бежать", "irreg-спать", "irreg-хотеть", "irreg-дать",
    "irreg-есть", "irreg-сыпать", "irreg-лгать", "irreg-мочь",
    "irreg-слать", "irreg-идти", "irreg-ехать", "irreg-минуть",
    "irreg-живописать-миновать", "irreg-лечь", "irreg-зиждиться",
    "irreg-клясть", "irreg-слыхать-видать", "irreg-стелить-стлать",
    "irreg-быть", "irreg-ссать-сцать", "irreg-чтить", "irreg-шибить",
    "irreg-плескать", "irreg-реветь", "irreg-внимать", "irreg-внять",
    "irreg-обязывать"]
for i, ty in blib.iter_items(types, start, end):
  template_page = pywikibot.Page(site, "Template:ru-conj-%s" % ty)
  if template_page.exists():
    template_page.delete("Replace with template ru-conj")
  template_doc_page = pywikibot.Page(site, "Template:ru-conj-%s/documentation" % ty)
  if template_doc_page.exists():
    template_doc_page.delete("Replace with template ru-conj")
