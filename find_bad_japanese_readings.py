#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_page(page, index):
  pagetitle = str(page.title())
  for i, catpage in blib.cat_subcats(page, recurse=True):
    cat = str(catpage.title())
    def pagemsg(txt):
      msg("Page %s,%s %s: %s" % (index, i, cat, txt))
    if (not re.search("with.* reading ", cat) or re.search("(ancient|historical) ", cat) or re.search("read as", cat)):
      continue
    reading = re.sub(".*with.* reading ", "", cat)
    reading = re.sub("-.*", "", reading)
    reason = None
    if len(reading) > 5:
      reason = ">5 chars"
    elif reading.endswith("さま"):
      reason = "ends with さま"
    elif re.search("[をゑゐ]|[かがはばぱさざただなまやら]う", reading):
      reason = "contains archaic chars or inappropriate combinations"
    if reason:
      kanjis = []
      for j, kanjipage in blib.cat_articles(catpage):
        kanji = str(kanjipage.title())
        kanjis.append(kanji)
      pagemsg("Bad category because %s: contents=%s" % (reason, ",".join(kanjis)))

parser = blib.create_argparser("Find bad Japanese reading categories", include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page)
