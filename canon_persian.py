#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
import fa_translit
from canon_foreign import canon_one_page_links

parser = blib.create_argparser("Clean up Persian transliterations",
    include_pagefile=True)
parser.add_argument("--direcfile", help="File containing output from find_regex.py, to process")
parser.add_argument("--test", help="Test fa_translit.py", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates_seen = {}
templates_changed = {}
def process_text_on_page(index, pagetitle, text):
  if args.test:
    def process_param(obj):
      def getp(param):
        return getparam(obj.t, param)
      def test(foreign, latin):
        return fa_translit.test(latin, foreign, "matched")
      if obj.param[0] == "separate":
        _, foreign, latin = obj.param
        test(getp(foreign), getp(latin))
      elif obj.param[0] == "separate-pagetitle":
        _, foreign_dest, latin = obj.param
        test(pagetitle, getp(latin))
      elif obj.param[0] == "inline":
        _, foreign_param, foreign_mod, latin_mod, inline_mod = obj.param
        test(inline_mod.mainval if foreign_mod is None else inline_mod.get_modifier(foreign_mod),
            inline_mod.get_modifier(latin_mod))
    text, actions = blib.process_one_page_links(index, pagetitle, text, ["fa"], process_param,
        templates_seen, templates_changed)
    return text, actions
  return canon_one_page_links(pagetitle, index, text, "fa", "fa-Arab", fa_translit,
      templates_seen, templates_changed)

if args.direcfile:
  for lineindex, line in blib.iter_items_from_file(args.direcfile, start, end):
    lineno = lineindex + 1
    def linemsg(text):
      msg("Line %s: %s" % (lineno, text))
    m = re.search("^Page ([0-9]+) (.*?): (.*)$", line)
    if not m:
      linemsg("WARNING: Unrecognized line: %s" % line)
    else:
      index, pagetitle, text = m.groups()
      process_text_on_page(index, pagetitle, text)
else:
  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
blib.output_process_links_template_counts(templates_seen, templates_changed)
