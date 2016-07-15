#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse

from blib import msg
import rulib as ru

parser = argparse.ArgumentParser(description="Generate derived-verb tables.")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

def render_groups(groups):
  def is_noequiv(x):
    return x == "* (no equivalent)"
  def compare_aspect_pair(xpf, ximpf, ypf, yimpf):
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
  def sort_aspect_pair(x, y):
    xpf, ximpf = x
    ypf, yimpf = y
    # First compare ignoring accents, so that влить goes before вли́ться,
    # then compare with accents so e.g. рассы́пать and рассыпа́ть are ordered
    # consistently.
    retval = compare_aspect_pair(ru.remove_accents(xpf), ru.remove_accents(ximpf),
      ru.remove_accents(ypf), ru.remove_accents(yimpf))
    if retval == 0:
      return compare_aspect_pair(xpf, ximpf, ypf, yimpf)
    else:
      return retval

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

def combine_prefix(prefix, suffix):
  if ru.is_stressed(prefix):
    return "* {{l|ru|" + prefix + ru.make_unstressed(suffix) + "}}"
  else:
    return "* {{l|ru|" + prefix + suffix + "}}"
# Each group is delineated by a line containing only a hyphen in the
# directive file, and consists of a list of (pf, impf) pairs. Multiple tables
# are delineated by a line containing two or more hyphens.
groups = []
group = []
pfsuffix = None
impfsuffix = None
for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  if not line or line.startswith("#"):
    pass # Skip blank and comment lines
  elif re.search("^--+$", line):
    # End of table; other tables may follow
    if group:
      groups.append(group)
    if groups:
      render_groups(groups)
    groups = []
    group = []
    pfsuffix = None
    impfsuffix = None
  elif line == "-":
    if group:
      groups.append(group)
    group = []
  elif " " not in line:
    group.append((combine_prefix(line, pfsuffix),
        combine_prefix(ru.make_unstressed(line), impfsuffix)))
  elif "!" in line:
    pf, impf = re.split(r"\s+", line)
    assert pf == "!" or impf == "!"
    if pf == "!":
      group.append(("* (no equivalent)", combine_prefix(ru.make_unstressed(impf), impfsuffix)))
    else:
      group.append((combine_prefix(pf, pfsuffix), "* (no equivalent)"))
  else:
    pf, impf = re.split(r"\s+", line)
    if pf.startswith("-") and impf.startswith("-"):
      pfsuffix = re.sub("^-", "", pf)
      impfsuffix = re.sub("^-", "", impf)
      continue
    def do_line(direc, aspect):
      links = []
      if direc == "-":
        return "* (no equivalent)"
      else:
        for verb in re.split(",", direc):
          gender = ""
          notes = []
          while True:
            if verb.startswith("+"):
              gender = "|g=%s" % aspect
              verb = re.sub(r"^\+", "", verb)
            elif verb.startswith("(i)"):
              notes.append("iterative")
              verb = re.sub(r"^\(i\)", "", verb)
            elif verb.startswith("(n)"):
              notes.append("nonstandard")
              verb = re.sub(r"^\(n\)", "", verb)
            elif verb.startswith("(d)"):
              notes.append("dated")
              verb = re.sub(r"^\(d\)", "", verb)
            else:
              break
          m = re.search(r"^\[(.*)\]$", verb)
          if m:
            links.append("[{{l|ru|%s%s}}]%s" % (m.group(1), gender,
              notes and " {{i|%s}}" % ", ".join(notes) or ""))
          else:
            links.append("{{l|ru|%s%s}}%s" % (verb, gender,
              notes and " {{i|%s}}" % ", ".join(notes) or ""))
        return "* " + ", ".join(links)
    group.append((do_line(pf, "pf"), do_line(impf, "impf")))

if group:
  groups.append(group)
if groups:
  render_groups(groups)
