#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from collections import defaultdict
import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  newtext = re.sub("^(===Pronunciation===\n.*?\n)(===Etymology===\n.*?\n)==",
      r"\2\1==", text, 0, re.S | re.M)
  return newtext, "put Etymology before Pronunciation"

parser = blib.create_argparser("Put Etymology before Pronunciation",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
