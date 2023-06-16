#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_line(index, line):
  line = line.strip()
  m = re.search("^Page [0-9]+ (.*?): Replaced <.*?> with <(.*?)>$", line)
  if not m:
    msg("WARNING: Unrecognized line: %s" % line)
    return
  pagetitle, text = m.groups()
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "place":
      numargs = []
      for i in range(1, 40):
        param = getparam(t, str(i))
        if param:
          numargs.append(param)
      runs = []
      run = []
      for arg in numargs[1:]:
        if arg == ";":
          if run:
            runs.append(run)
            run = []
        else:
          run.append(arg)
      if run:
        runs.append(run)
      if len(runs) == 2 and len(runs[1]) == 2 and (
          runs[1][0] in ["county seat", "parish seat", "borough seat"] and
          re.search(r"^(co|par|bor)/", runs[1][1])):
        if (len(runs[0]) >= 4 and runs[0][1].startswith("co/") and runs[0][2] == "and" and
            runs[0][3].startswith("co/")):
          numargs = ([numargs[0], "%s/%s" % (runs[0][0], runs[1][0]), runs[1][1]] +
              runs[0][4:] + ["located in"] + runs[0][1:4])
        else:
          numargs = [numargs[0], "%s/%s" % (runs[0][0], runs[1][0]), runs[1][1]] + runs[0][1:]
        non_numbered_params = []
        for param in t.params:
          pname = str(param.name).strip()
          pval = str(param.value).strip()
          showkey = param.showkey
          if not re.search("^[0-9]+$", pname):
            non_numbered_params.append((pname, pval, showkey))
        namedargs = "".join("|%s=%s" % (pname, pval) for pname, pval, showkey in non_numbered_params)
        pagemsg("<from> %s <to> {{place|%s%s}} <end>" % (
          str(t), "|".join(numargs), namedargs))
      else:
        pagemsg("WARNING: Don't recognize structure of place template: %s" % str(t))

parser = blib.create_argparser("Remove redundant manually-added categories when {{place}} also adds them")
parser.add_argument("--direcfile", help="File containing lines from templatize_place.py", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for index, line in blib.iter_items_from_file(args.direcfile, start, end):
  process_line(index, line)
