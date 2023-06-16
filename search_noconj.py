#!/usr/bin/env python
# -*- coding: utf-8 -*-

import blib
from blib import msg, getparam, addparam

def search_noconj(startFrom, upTo):
  for index, page in blib.cat_articles(u"Arabic verbs", startFrom, upTo):
    text = str(blib.parse(page))
    pagetitle = page.title()
    if "{{ar-verb" not in text:
      msg("* ar-verb not in {{l|ar|%s}}" % pagetitle)
    if "{{ar-conj" not in text:
      msg("* ar-conj not in {{l|ar|%s}}" % pagetitle)

startFrom, upTo = blib.parse_args()

search_noconj(startFrom, upTo)
