#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys, argparse

from blib import msg
import blib
import rulib

parser = blib.create_argparser("Generate derived-verb tables.")
parser.add_argument('--direcfile', help="File containing directives.", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

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
    retval = compare_aspect_pair(rulib.remove_accents(xpf), rulib.remove_accents(ximpf),
      rulib.remove_accents(ypf), rulib.remove_accents(yimpf))
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
{{bottom}}
""" % ("\n".join(impfs), "\n".join(pfs)))

def paste_verb(prefix, suffix):
  if rulib.is_stressed(prefix):
    verb = prefix + rulib.make_unstressed_ru(suffix)
  else:
    verb = prefix + suffix
  return rulib.remove_monosyllabic_accents(verb)

def combine_prefix(prefix, suffixes, aspect):
  # If the prefix starts with +, include the aspect. See лететь.der for
  # a good example.
  add_aspect = False
  if prefix.startswith("+"):
    add_aspect = True
    prefix = prefix[1:]
  links = []
  for suffix in suffixes:
    links.append("{{l|ru|" + paste_verb(prefix, suffix) +
        ("|g=%s" % aspect if add_aspect else "") + "}}")
  return "* " + ", ".join(links)

# Each group is delineated by a line containing only a hyphen in the
# directive file, and consists of a list of (pf, impf) pairs. Multiple tables
# are delineated by a line containing two or more hyphens.
groups = []
group = []
pfsuffixes = None
impfsuffixes = None
for lineno, line in blib.iter_items_from_file(args.direcfile, start, end):
  if re.search("^--+$", line):
    # End of table; other tables may follow
    if group:
      groups.append(group)
    if groups:
      render_groups(groups)
    groups = []
    group = []
    pfsuffixes = None
    impfsuffixes = None
  elif line == "-":
    if group:
      groups.append(group)
    group = []
  elif " " not in line:
    # A single prefix; combine with previous suffixes.
    # If it starts with a + (indicating include the apsect), that applies
    # only to the perfective verb. See лететь.der for good examples.
    group.append((combine_prefix(line, pfsuffixes, "pf"),
        combine_prefix(rulib.make_unstressed_ru(line).replace("+", ""), impfsuffixes, "impf")))
  elif re.search(r" \+$", line):
    # Something like "об +" or "+об +". This indicates that the imperfective
    # (and maybe the perfective) should include the aspect. See лететь.der
    # for good examples.
    pf, impf = re.split(r"\s+", line)
    assert impf == "+"
    group.append((combine_prefix(pf, pfsuffixes, "pf"),
        combine_prefix("+" + rulib.make_unstressed_ru(pf), impfsuffixes, "impf")))
  elif "!" in line:
    # Something like "об !" or "+об !" or "! об" or "! +об". This indicates
    # that one of the two is missing and the other should combine with
    # previous suffixes, maybe with the aspect included (see лететь.der for
    # good examples of this).
    pf, impf = re.split(r"\s+", line)
    assert pf == "!" or impf == "!"
    if pf == "!":
      group.append(("* (no equivalent)", combine_prefix(rulib.make_unstressed_ru(impf), impfsuffixes, "impf")))
    else:
      group.append((combine_prefix(pf, pfsuffixes, "pf"), "* (no equivalent)"))
  else:
    # Something like "обмени́ть,обменя́ть обме́нивать" or "+переменя́ться -".
    # We directly include the perfective and imperfective verb(s), where
    # a lone "-" means to not include it, and a prefixed "+" means to
    # include the aspect.
    pf, impf = re.split(r"\s+", line)
    if pf.startswith("-") and impf.startswith("-"):
      pfsuffixes = [re.sub("^-", "", x) for x in re.split(",", pf)]
      impfsuffixes = [re.sub("^-", "", x) for x in re.split(",", impf)]
      continue
    def do_line(direc, aspect, suffixes):
      links = []
      if direc == "-":
        return "* (no equivalent)"
      else:
        for index, verb in enumerate(re.split(",", direc)):
          gender = ""
          notes = []
          if verb:
            endbracket = False
            if verb.endswith("]"):
              endbracket = True
              verb = verb[:-1]
            if verb.endswith("-"):
              verb = verb[:-1]
              if aspect == "impf":
                verb = rulib.make_unstressed_ru(verb)
              verb = paste_verb(verb, suffixes[index])
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
              elif verb.startswith("(lc)"):
                notes.append("low colloquial")
                verb = re.sub(r"^\(lc\)", "", verb)
              elif verb.startswith("(d)"):
                notes.append("dated")
                verb = re.sub(r"^\(d\)", "", verb)
              else:
                break
            if verb.startswith("["):
              verb = verb[1:]
              assert endbracket
              links.append("[{{l|ru|%s%s}}]%s" % (verb, gender,
                notes and " {{i|%s}}" % ", ".join(notes) or ""))
            else:
              links.append("{{l|ru|%s%s}}%s" % (verb, gender,
                notes and " {{i|%s}}" % ", ".join(notes) or ""))
        return "* " + ", ".join(links)
    group.append((do_line(pf, "pf", pfsuffixes), do_line(impf, "impf", impfsuffixes)))

if group:
  groups.append(group)
if groups:
  render_groups(groups)
