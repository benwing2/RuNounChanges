#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse, codecs

parser = argparse.ArgumentParser(description="Create input file for running find_misformatted_sections.py on multiple languages")
parser.add_argument("--direcfile", help="File listing languages", required=True)
parser.add_argument("--tag", help="Tag identifying this run", default="jeff-doozan")
args = parser.parse_args()

lines = codecs.open(args.direcfile.decode("utf-8"), "r", encoding="utf-8")
for line in lines:
  lang = line.strip()
  lclang = lang.lower().replace(" ", "-").replace("(", "").replace(")", "").replace("'", "")
  cmd = "python find_misformatted_sections.py --cats \"%s lemmas\" --correct --diff --save > find_misformatted_sections.%s-lemmas.out.1.%s.save" % (lang, lclang, args.tag.decode("utf-8"))
  echocmd = cmd.replace("'", "\\'").replace('"', '\'"\'').replace(">", '">"').replace("(", "'('").replace(")", "')'")
  print ("echo %s" % echocmd).encode("utf-8")
  print cmd.encode("utf-8")
