#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg, errmsg
import rulib

parser = argparse.ArgumentParser(description="Find lemmas which would have forms saved.")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

lemmas = set()

for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  if "Would save with comment" in line:
    m = re.search("Would save with comment.* (?:of|dictionary form) (.*?)(,| after| before| \(add| \(modify| \(update|$)", line)
    if not m:
      errmsg("WARNING: Unable to parse line: %s" % line)
    else:
      lemmas.add(rulib.remove_accents(m.group(1)))
for lemma in sorted(lemmas):
  print lemma.encode('utf-8')
