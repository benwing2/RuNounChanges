#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib
import json

lang_outfile = "lang-data.json"
etymlang_outfile = "etymlang-data.json"
family_outfile = "family-data.json"
script_outfile = "script-data.json"

blib.getData()

with open(lang_outfile, "w") as fp:
  for lang in blib.languages:
    fp.write(json.dumps(lang) + "\n")

with open(etymlang_outfile, "w") as fp:
  for lang in blib.etym_languages:
    fp.write(json.dumps(lang) + "\n")

with open(family_outfile, "w") as fp:
  for fam in blib.families:
    fp.write(json.dumps(fam) + "\n")

with open(script_outfile, "w") as fp:
  for scr in blib.scripts:
    fp.write(json.dumps(scr) + "\n")
