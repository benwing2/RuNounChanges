#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys, argparse
import fileinput

import blib
from blib import msg, errmsg

parser = blib.create_argparser("Augment Chinese variety counts with locations and links")
parser.add_argument("--counts")
parser.add_argument("--zh-data-dial")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

variety_data = {}
cur_variety = None
for line in open(args.zh_data_dial, "r"):
  line = line.strip()
  m = re.search(r'^variety_data\["(.*?)"\] *= *\{', line)
  if m:
    cur_variety = m.group(1)
    variety_data[cur_variety] = {}
  m = re.search(r'group = "(.*?)"', line)
  if m:
    if not cur_variety:
      errmsg("WARNING: Found group = ... outside of a variety clause: %s" % line)
    else:
      variety_data[cur_variety]["group"] = m.group(1)
  m = re.search(r'link = "(.*?)"', line)
  if m:
    if not cur_variety:
      errmsg("WARNING: Found link = ... outside of a variety clause: %s" % line)
    else:
      variety_data[cur_variety]["link"] = m.group(1)

for line in open(args.counts, "r"):
  line = line.strip()
  m = re.search(r"^\| (.*?) \|\| ([0-9]+)$", line)
  if m:
    variety, count = m.groups()
    if variety in variety_data:
      vardata = variety_data[variety]
    else:
      errmsg("WARNING: Found variety '%s' not in variety data" % variety)
      vardata = {}
    if "link" in vardata:
      link = "{{w|%s}}" % vardata["link"]
    else:
      link = "N/A"
    msg("| %s || %s || %s || %s" % (variety, count, vardata.get("group", "???"), link))
  else:
    msg(line)
