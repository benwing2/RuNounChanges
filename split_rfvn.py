#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

cjk_chars = u"[\u1100-\u11FF\u2E80-\uA4FF\uAC00-\uD7FF\uFF00-\uFFEF]|[\uD840-\uD8BF]."

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  months = re.split("(^=[^=].*\n)", text, 0, re.M)

  extracted_parts = [months[0]]

  for j in xrange(2, len(months), 2):
    month = re.sub(r"^\s*=+\s*(.*?)\s*=+\s*$", r"\1", months[j - 1])
    extracted_in_month = []
    level2_secs = re.split("(^==[^=].*\n)", months[j], 0, re.M)
    for k in xrange(2, len(level2_secs), 2):
      is_cjk = re.search(cjk_chars, level2_secs[k - 1]) or re.search("-notice-(zh|ja|ko)-", level2_secs[k - 1])
      if not args.invert and is_cjk or args.invert and not is_cjk:
        this_header = re.sub(r"^\s*=+\s*(.*?)\s*=+\s*$", r"\1", level2_secs[k - 1])
        pagemsg("Extracting %s: %s" % (month, this_header))
        extracted_in_month.append(level2_secs[k - 1] + level2_secs[k])
    if extracted_in_month:
      extracted_parts.append(months[j - 1])
      extracted_parts.append(level2_secs[0])
      extracted_parts.extend(extracted_in_month)

  return "".join(extracted_parts), args.invert and "extract non-CJK entries" or "extract CJK entries"

parser = blib.create_argparser("Extract CJK or non-CJK entries from [[WT:RFVN]]",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--invert", action="store_true", help="Include non-CJK entries")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
