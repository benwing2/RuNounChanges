#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, codecs, argparse
from blib import msg
import blib
import rulib

parser = argparse.ArgumentParser(description="Make bare and list versions of 10,000-word frequency list from the Internet.")
parser.add_argument('--file', help="File containing original list.")
args = parser.parse_args()

for line in codecs.open(args.file, "r", "utf-8"):
  line = line.strip()
  line = re.sub(" .*", "", line)
  line = rulib.remove_accents(line)
  if "/" in line:
    els = re.split("/", line)
    impf = els[0]
    msg(impf)
    for pf in els[1:]:
      if pf.endswith("-"):
        pf = re.sub("-$", impf, pf)
      msg(pf)
  else:
    msg(line)
