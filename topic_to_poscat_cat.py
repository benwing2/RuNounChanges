#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

blib.getLanguageData()

parser = blib.create_argparser("Move categories based on a regex", include_pagefile=True, include_stdin=True)
parser.add_argument("--from", help="Old name of template; can be specified multiple times",
    metavar="FROM", dest="from_", action="append", required=True)
parser.add_argument("--to", help="New name of template; can be specified multiple times",
    action="append", required=True)
parser.add_argument("--direcfile", help="File containing categories", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

num_moves = len(args.from_)
if num_moves != len(args.to):
  raise ValueError("Saw %s 'from' spec(s) '%s' but %s 'to' spec(s) '%s'; both must agree in number" % (
      (len(args.from_), ",".join(args.from_), len(args.to), ",".join(args.to))))
moves_to_do = list(zip(args.from_, args.to))

for index, line in blib.iter_items_from_file(args.direcfile, start, end):
  def linemsg(txt):
    msg("Line %s: %s" % (index, txt))
  m = re.search("^Category:(.*?):(.*)$", line)
  if not m:
    linemsg("WARNING: Unrecognized line: %s" % line)
  else:
    langcode, cat = m.groups()
    if langcode not in blib.languages_byCode:
      linemsg("WARNING: Unrecognized lang code '%s': %s" % (langcode, line))
      continue
    origcat = cat
    for fromre, tore in moves_to_do:
      cat = re.sub(fromre, tore, cat)
    msg("Category:%s:%s ||| Category:%s %s" % (langcode, origcat, blib.languages_byCode[langcode]["canonicalName"], cat))
