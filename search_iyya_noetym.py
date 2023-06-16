#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib
from blib import msg, getparam, addparam

def search_iyya_noetym(startFrom, upTo):
  for index, page in blib.cat_articles(u"Arabic nouns", startFrom, upTo):
    text = blib.parse(page)
    pagetitle = page.title()
    etym = False
    suffix = False
    if pagetitle.endswith(u"ية"):
      for t in text.filter_templates():
        if t.name in ["ar-etym-iyya", "ar-etym-nisba-a",
            "ar-etym-noun-nisba", "ar-etym-noun-nisba-linking"]:
          etym = True
        if t.name == "suffix":
          suffix = True
      if not etym:
        msg("Page %s %s: Ends with -iyya, no appropriate etym template%s" % (
          index, pagetitle, " (has suffix template)" if suffix else ""))

startFrom, upTo = blib.parse_args()

search_iyya_noetym(startFrom, upTo)
