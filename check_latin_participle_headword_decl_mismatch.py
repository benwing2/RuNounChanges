#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, errmsg, site

import lalib

parser = blib.create_argparser("Check for mismatch between participle headword and decl")
parser.add_argument("--direcfile", help="Output from find_template.participles.*.",
    required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

last_part_headword = None
last_adecl_headword = None
for lineno, line in blib.iter_items_from_file(args.direcfile, start, end):
  def err(text):
    msg("Line %s: %s" % (lineno, text))
  m = re.search(r"Found la-part template: \{\{la-part\|(.*?)(\|.*)?\}\}", line)
  if m:
    last_part_headword = m.group(1)
  m = re.search(r"Found la-adecl template: (\{\{la-adecl\|(.*?)(<.*>)?\}\})", line)
  if m:
    adecl_headword = m.group(2)
    if adecl_headword == last_adecl_headword:
      continue
    last_adecl_headword = adecl_headword
    if last_part_headword != last_adecl_headword:
      err("Mismatch between {{la-part|%s}} and %s" % (last_part_headword, m.group(1)))
    last_part_headword = None
