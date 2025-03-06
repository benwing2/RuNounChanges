#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse, json, re, os

parser = argparse.ArgumentParser(description="Convert MediaWiki Babel extension data to a Lua data file.")
parser.add_argument("--directory", help="Directory containing JSON JSON files.", required=True)
parser.add_argument("--comment", help="Comment to add at top of file (esp. indicating the source version of the data.")
args = parser.parse_args()

from os import listdir
from os.path import isfile, join
dir_files = [join(args.directory, f) for f in listdir(args.directory)]
dir_json_files = sorted(f for f in dir_files if isfile(f) and f.endswith(".json"))

output = []
def ins(txt):
  output.append(txt)
ins("return {")
if args.comment:
  ins("\t-- %s" % args.comment)
for json_file in dir_json_files:
  data = json.loads(open(json_file).read())
  langcode = re.sub(r"\.json$", "", re.sub(".*/", "", json_file))
  ins("")
  ins("\t-------------------------- %s --------------------------" % langcode)
  for suf in ["-n", ""]:
    lines = []
    for level in ["0", "1", "2", "3", "4", "5", "N"]:
      key = "babel-%s%s" % (level, suf)
      if key in data:
        lines.append('\t["%s-%s"] = "%s",' % (langcode, level, data[key].replace("\n", r"\n")))
    if lines:
      if suf == "":
        ins("\t-- (based on plain versions missing language name)")
      output.extend(lines)
      break
  else: # no break
    ins("\t-- (no competency data in file)")
ins("}")

print("\n".join(output) + "\n")
