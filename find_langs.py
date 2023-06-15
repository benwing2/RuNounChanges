#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  #pagemsg("Processing")

  if blib.page_should_be_ignored(pagetitle):
    #pagemsg("WARNING: Page should be ignored")
    return

  sections = re.split("(^==[^=\n]+==\n)", text, 0, re.M)
  langs = []
  for j in range(1, len(sections), 2):
    m = re.search("^==(.*)==$", sections[j])
    langs.append(m.group(1))
  pagemsg("Languages = %s" % ",".join(langs))

parser = blib.create_argparser("Find languages on pages")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.parse_dump(sys.stdin, process_text_on_page, startprefix=start, endprefix=end)
