#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, errmsg, site

import lalib

parser = blib.create_argparser("Fix old-style verb declarations in latin-macrons.txt")
parser.add_argument("--direcfile", help="List of directives to process.",
    required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for lineno, line in blib.iter_items_from_file(args.direcfile, start, end):
  def err(text):
    errmsg("Line %s: %s" % (lineno, text))
  # break off transitive/intransitive notation after verbs
  m = re.search(r"^(.*?)((?: *\[.*\])?)$", line)
  parttext, transtext = m.groups()
  parts = parttext.split(" ")
  if parts[0] in ["adv", "num", "phr", "prep", "prov"] or re.search(r"^(n|pn|a|num|part|v)([1-5]|irreg)?\+?$", parts[0]):
    msg(line)
    continue

  if len(parts) != 3 and len(parts) != 4:
    err("Bad line: %s" % line)
    continue
  if len(parts) == 3:
    # deponent
    lemma, inf, supine = parts
    if supine == "--":
      supine = None
    else:
      supines = supine.split("/")
      supine_bases = []
      must_continue = False
      for sup in supines:
        if not sup.endswith("um"):
          err("Bad supine %s: %s" % (sup, line))
          must_continue = True
          continue
        supine_bases.append(sup[:-2])
      if must_continue:
        continue
      supine = "/".join(supine_bases)
    if lemma.endswith("ior") and lemma[:-3] + "ī" == inf:
      vtype = "v3"
    elif lemma.endswith("ior") and lemma[:-3] + "īrī" == inf:
      vtype = "v4"
    elif lemma.endswith("eor") and lemma[:-3] + "ērī" == inf:
      vtype = "v2"
    elif lemma.endswith("or") and lemma[:-2] + "ī" == inf:
      vtype = "v3"
    elif lemma.endswith("or") and lemma[:-2] + "ārī" == inf:
      vtype = "v1"
    else:
      err("Unrecognized infinitive %s for lemma %s: %s" % (inf, lemma, line))
      continue
    if supine:
      msg("%s %s %s%s" % (vtype, lemma, supine, transtext))
    else:
      msg("%s %s%s" % (vtype, lemma, transtext))
  else:
    lemma, inf, perfect, supine = parts
    if supine == "--":
      supine = None
    else:
      supines = supine.split("/")
      supine_bases = []
      must_continue = False
      for sup in supines:
        if not sup.endswith("um"):
          err("Bad supine %s: %s" % (sup, line))
          must_continue = True
          continue
        supine_bases.append(sup[:-2])
      if must_continue:
        continue
      supine = "/".join(supine_bases)
    if perfect == "--":
      perfect = ""
    else:
      perfects = perfect.split("/")
      perfect_bases = []
      must_continue = False
      for perf in perfects:
        if perf.endswith("ī"):
          perfect_bases.append(perf[:-1])
        elif perf.endswith("it"):
          perfect_bases.append(perf[:-2])
        else:
          err("Bad perfect %s: %s" % (perf, line))
          must_continue = True
          continue
      if must_continue:
        continue
      perfect = "/".join(perfect_bases)
    if lemma.endswith("iō") and lemma[:-2] + "ere" == inf:
      vtype = "v3"
    elif lemma.endswith("iō") and lemma[:-2] + "īre" == inf:
      vtype = "v4"
    elif lemma.endswith("eō") and lemma[:-2] + "ēre" == inf:
      vtype = "v2"
    elif lemma.endswith("ō") and lemma[:-1] + "ere" == inf:
      vtype = "v3"
    elif lemma.endswith("ō") and lemma[:-1] + "āre" == inf:
      vtype = "v1"
    else:
      err("Unrecognized infinitive %s for lemma %s: %s" % (inf, lemma, line))
      continue
    if not perfect and not supine:
      msg("%s %s%s" % (vtype, lemma, transtext))
    elif not supine:
      msg("%s %s %s%s" % (vtype, lemma, perfect, transtext))
    elif not perfect:
      msg("%s %s -- %s%s" % (vtype, lemma, supine, transtext))
    else:
      msg("%s %s %s %s%s" % (vtype, lemma, perfect, supine, transtext))
