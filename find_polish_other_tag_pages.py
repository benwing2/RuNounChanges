#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

parser = blib.create_argparser("Clean up bad inflection tags")
parser.add_argument("--textfile", help="Pages and inflections to process.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

with open(args.textfile, "r", encoding="utf-8") as fp:
  text = fp.read()
  pages = text.split('\001')
for index, page in blib.iter_items(pages, start, end):
  if not page: # e.g. first entry
    continue
  split_vals = re.split("\n", page, 1)
  if len(split_vals) < 2:
    msg("Page %s: Skipping bad text: %s" % (index, page))
    continue
  pagetitle, pagetext = split_vals
  parsed = blib.parse_text(pagetext)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "inflection of":
      lang = getparam(t, "lang")
      if not lang:
        lang = getparam(t, "1")
      if lang == "pl":
        for param in t.params:
          pname = str(param.name).strip()
          pval = str(param.value).strip()
          if re.search("^[0-9]+$", pname) and pval == "other":
            msg(pagetitle)
