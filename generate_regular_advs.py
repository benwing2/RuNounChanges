#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse
import fileinput

from blib import msg, errmsg
import rulib

for line in fileinput.input():
  line = line.strip()
  args = re.split(" +", line)
  assert len(args) in [1, 2]
  adv = args[0]
  assert adv.endswith(u"о")
  negbez = [] if len(args) == 1 else re.split(",", args[1])
  adj = re.sub("о$", "ий" if adv.endswith("ко") else "ый", adv)
  rels = []
  rels.append(adj)
  for nb in negbez:
    if nb == "neg":
      rels.append("не" + adj)
    elif nb == "bez":
      if re.search("^[пткцчсшщфх]", adj):
        rels.append("бес" + adj)
      else:
        rels.append("без" + adj)
  msg("%s %s+-о - rel:%s" % (adv, adj, ":".join(rels)))
