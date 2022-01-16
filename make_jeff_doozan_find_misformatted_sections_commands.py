#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse, codecs

parser = argparse.ArgumentParser(description="Create input file for running find_misformatted_sections.py on multiple languages")
parser.add_argument("--direcfile", help="File listing languages")
args = parser.parse_args()

lines = codecs.open(args.direcfile, "r", encoding="utf-8")
for line in lines:
  lang = line.strip()
  lclang = lang.lower().replace(" ", "-").replace("(", "").replace(")", "").replace("'", "")
  cmd = "python find_misformatted_sections.py --cats \"%s lemmas\" --correct --diff --save > find_misformatted_sections.%s-lemmas.out.1.jeff-doozan.save" % (lang, lclang)
  echocmd = cmd.replace("'", "\\'").replace('"', '\'"\'').replace(">", '">"').replace("(", "'('").replace(")", "')'")
  print "echo %s" % echocmd
  print cmd
