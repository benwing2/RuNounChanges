#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse
import fileinput

from blib import msg, errmsg
import rulib

for line in fileinput.input():
  line = line.strip()
  line = line.decode("utf-8")
  args = re.split(" +", line)
  assert len(args) in [1, 2]
  adv = args[0]
  assert adv.endswith(u"о")
  negbez = [] if len(args) == 1 else re.split(",", args[1])
  adj = re.sub(u"о$", u"ий" if adv.endswith(u"ко") else u"ый", adv)
  rels = []
  rels.append(adj)
  for nb in negbez:
    if nb == "neg":
      rels.append(u"не" + adj)
    elif nb == "bez":
      if re.search(u"^[пткцчсшщфх]", adj):
        rels.append(u"бес" + adj)
      else:
        rels.append(u"без" + adj)
  msg(u"%s %s+-о - rel:%s" % (adv, adj, ":".join(rels)))
