#!/usr/bin/env python
# -*- coding: utf-8 -*-

import fileinput
from collections import defaultdict

groups = defaultdict(list)
for line in fileinput.input():
  prefix, rest = line.strip().split("\t")
  groups[prefix] += [rest]
for prefix, rests in sorted(list(groups.iteritems())):
  print "| %s || %s || %s" % (len(rests), prefix, " / ".join("[[:Category:%s|%s]]" % (x, x) for x in rests))
