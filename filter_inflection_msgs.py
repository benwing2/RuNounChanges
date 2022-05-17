#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg, errmsg
import rulib

parser = argparse.ArgumentParser(description="Filter inflection messages to those which would have forms saved.")
parser.add_argument('--direcfile', help="File containing inflection messages.")
args = parser.parse_args()

pagenos = set()

for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  if "Would save with comment" in line:
    m = re.search("^Page ([0-9]+) .*Would save with comment.* (?:of|dictionary form) (.*?)(,| after| before| \(add| \(modify| \(update|$)", line)
    if not m:
      errmsg("WARNING: Unable to parse line: %s" % line)
    else:
      pagenos.add(m.group(1))

for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  m = re.search("^Page ([0-9]+) ", line)
  if not m or m.group(1) in pagenos:
    print line.encode("utf-8")
