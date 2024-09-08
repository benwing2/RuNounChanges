#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
from collections import defaultdict

pages_by_num_ar_verb_forms = defaultdict(list)

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  num_ar_verb_forms = len(text.split("{{ar-verb-form|")) - 1
  if num_ar_verb_forms > 0:
    pages_by_num_ar_verb_forms[num_ar_verb_forms].append(pagetitle)

parser = blib.create_argparser("Count number of {{ar-verb-form}} occurrences on each page",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

for num_occur, pages in sorted(pages_by_num_ar_verb_forms.items(), reverse=True):
  msg("%2d = %s" % (num_occur, ",".join(pages)))
