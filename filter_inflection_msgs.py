#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys, argparse

from blib import msg, errmsg
import rulib

parser = blib.create_argparser("Filter inflection messages to those which would have forms saved.")
parser.add_argument('--direcfile', help="File containing inflection messages.", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pagenos = set()

for lineno, line in blib.iter_items_from_file(args.direcfile, start, end):
  if "Would save with comment" in line:
    m = re.search("^Page ([0-9]+) .*Would save with comment.* (?:of|dictionary form) (.*?)(,| after| before| \(add| \(modify| \(update|$)", line)
    if not m:
      errmsg("WARNING: Unable to parse line: %s" % line)
    else:
      pagenos.add(m.group(1))

for lineno, line in blib.iter_items_from_file(args.direcfile, start, end):
  m = re.search("^Page ([0-9]+) ", line)
  if not m or m.group(1) in pagenos:
    print(line)
