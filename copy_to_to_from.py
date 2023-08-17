#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

import blib, pywikibot
from blib import msg, getparam, addparam
from collections import defaultdict

def process_direcfile(direcfile, start, end):
  template_changes = []
  for lineno, line in blib.iter_items_from_file(direcfile, start, end):
    repl_on_right = False
    m = re.search(r"^(Page [^ ]+ .*?: .*?: )(\{\{.*?\}\})( <- \{\{.*?\}\} \()(\{\{.*?\}\})(\))$",
        line)
    if not m:
      m = re.search(r"^(\* (?:Page [^ ]+ )?\[\[)(.*?)(\]\]: .*?: <nowiki>)(\{\{.*?\}\})( <- \{\{.*?\}\} \()(\{\{.*?\}\})(\)</nowiki>.*)$",
          line)
    if not m:
      m = re.search(r"^(Page [^ ]+ .*?: .* /// )(.*?)( /// )(.*?)($)", line)
      repl_on_right = True
    if m:
      beg, left, in_between, right, after = m.groups()
      if repl_on_right:
        to = right
      else:
        to = left
      msg("%s%s%s%s%s" % (beg, to, in_between, to, after))
    else:
      from_to_splits = re.split("(<from> .*? <to> .*? <end>)", line)
      for i in range(len(from_to_splits)):
        if i % 2 == 1:
          m = re.search("^<from> (.*?) <to> (.*?) <end>$", from_to_splits[i])
          assert m
          from_to_splits[i] = "<from> %s <to> %s <end>" % (m.group(2), m.group(2))
      msg("".join(from_to_splits))

params = blib.create_argparser("Copy TO to FROM in manual change direcfile",
  include_pagefile=True, include_stdin=True)
params.add_argument("--direcfile", help="File containing templates to change, as output by various scripts with --from-to",
    required=True)

args = params.parse_args()
start, end = blib.parse_start_end(args.start, args.end)
process_direcfile(args.direcfile, start, end)
