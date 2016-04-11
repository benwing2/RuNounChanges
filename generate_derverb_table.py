#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg
import rulib as ru

parser = argparse.ArgumentParser(description="Generate derived-verb tables.")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

# Each group is delineated by a line containing only a hyphen in the
# directive file, and consists of a list of (pf, impf) pairs.
groups = []
group = []
for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  if line == "-":
    if group:
      groups.append(group)
    group = []
  else:
    pf, impf = re.split(r"\s+", line)
    def do_line(direc, aspect):
      links = []
      if direc == "-":
        return "* (no equivalent)"
      else:
        for verb in re.split(",", direc):
          gender = ""
          if verb.startswith("+"):
            gender = "|g=%s" % aspect
            verb = re.sub("^\+", "", verb)
          links.append("{{l|ru|%s%s}}" % (verb, gender))
        return "* " + ", ".join(links)
    group.append((do_line(pf, "pf"), do_line(impf, "impf")))
if group:
  groups.append(group)

def is_noequiv(x):
  return x == "* (no equivalent)"
def sort_aspect_pair(x, y):
  xpf, ximpf = x
  ypf, yimpf = y
  xpf = ru.remove_accents(xpf)
  ypf = ru.remove_accents(ypf)
  if not is_noequiv(xpf) and not is_noequiv(ypf):
    return cmp(xpf, ypf)
  elif not is_noequiv(ximpf) and not is_noequiv(yimpf):
    return cmp(ximpf, yimpf)
  elif not is_noequiv(xpf) and not is_noequiv(yimpf):
    return cmp(xpf, yimpf)
  elif not is_noequiv(ximpf) and not is_noequiv(ypf):
    return cmp(ximpf, ypf)
  else:
    return 0

pfs = []
impfs = []
for gr in groups:
  gr = sorted(gr, cmp=sort_aspect_pair)
  for pf, impf in gr:
    pfs.append(pf)
    impfs.append(impf)

msg("""
====Derived terms====
{{top2}}
''imperfective''
%s
{{mid2}}
''perfective''
%s
{{bottom2}}
""" % ("\n".join(impfs), "\n".join(pfs)))
