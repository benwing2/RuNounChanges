#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, tname, pname, msg, site

label_params_with_underscores = defaultdict(int)
def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not re.search("== *Chinese *==", text):
    return
  sectext = blib.find_lang_section(text, "Chinese", None)
  if sectext and re.search(r"\{\{(%s)\|" % "|".join(blib.label_templates), sectext):
    parsed = blib.parse_text(sectext)

    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in blib.label_templates and getparam(t, "1") == "zh":
        label_params = blib.fetch_param_chain(t, "2")
        for i in range(0, len(label_params) - 2):
          if label_params[i + 1] == "_" and re.search("^[A-Z]", label_params[i + 2]):
            param_set = (label_params[i], label_params[i + 1], label_params[i + 2])
            label_params_with_underscores[param_set] += 1

parser = blib.create_argparser("Find Chinese labels with underscores between them",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

for k, v in sorted(label_params_with_underscores.items(), key=lambda x:-x[1]):
  msg("%50s %5s" % ("|".join(k), v))
