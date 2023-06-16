#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
import unicodedata

from collections import defaultdict

import blib
from blib import getparam, rmparam, tname, pname, msg, site

prefixes_by_length = defaultdict(lambda: defaultdict(list))

def process_page(page, index):
  global args

  pagetitle = str(page.title())
  for i in range(1, args.max_prefix_length + 1):
    if len(pagetitle) >= i:
      prefix = pagetitle[0:i]
      prefixes_by_length[i][prefix].append(pagetitle)

parser = blib.create_argparser("Snarf Italian pronunciations for fixing",
  include_pagefile=True)
parser.add_argument("--max-prefix-length", type=int, default=10, help="Maximum length of prefixes to check for")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page)

for i in range(1, args.max_prefix_length + 1):
  max_prefixes = sorted(list(prefixes_by_length[i].iteritems()), key=lambda x: -len(x[1]))
  msg("Prefix length = %s" % i)
  msg("------------------- begin -----------------------")
  for prefix, titles in max_prefixes:
    msg(("%%5d %%%ds %%s" % i) % (len(titles), prefix, ",".join(titles)))
  msg("-------------------  end  -----------------------")

