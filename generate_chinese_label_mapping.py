#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys, argparse
import fileinput

from blib import msg, errmsg
import rulib

for line in fileinput.input():
  line = line.strip()
  m = re.search(r"^labels\[(.*?)\] = \{(.*?)\}: (.*)$", line)
  if not m:
    errmsg("Skipping unparsable line: %s" % line)
    continue
  canon, aliases, code = m.groups()
  if "," in code:
    code = "[%s]" % ", ".join('"%s"' % c for c in code.split(","))
  else:
    code = '"%s"' % code
  msg('  %s: %s,' % (canon, code))
  if aliases:
    aliases = aliases.split(", ")
    for alias in aliases:
      msg('  %s: %s,' % (alias, code))
