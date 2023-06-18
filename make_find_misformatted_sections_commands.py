#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import blib

parser = blib.create_argparser("Create input file for running find_misformatted_sections.py on multiple languages")
parser.add_argument("--direcfile", help="File listing languages", required=True)
parser.add_argument("--tag", help="Tag identifying this run", default="jeff-doozan")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for lineno, lang = blib.iter_items_from_file(args.direcfile, start, end):
  lclang = lang.lower().replace(" ", "-").replace("(", "").replace(")", "").replace("'", "")
  cmd = "python find_misformatted_sections.py --cats \"%s lemmas\" --correct --diff --save > find_misformatted_sections.%s-lemmas.out.1.%s.save" % (lang, lclang, args.tag)
  echocmd = cmd.replace("'", "\\'").replace('"', '\'"\'').replace(">", '">"').replace("(", "'('").replace(")", "')'")
  print("echo %s" % echocmd)
  print(cmd)
