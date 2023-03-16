#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
import fa_translit
from canon_foreign import canon_one_page_links, show_failure

parser = blib.create_argparser("Clean up Persian transliterations", include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File containing output from find_regex.py, to process")
parser.add_argument("--test", help="Test fa_translit.py", action="store_true")
parser.add_argument("--no-vocalize", help="Disable vocalization of Persian script", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates_seen = {}
templates_changed = {}
printed_succeeded_failed = False

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  if args.test:
    def process_param(obj):
      def getp(param):
        return getparam(obj.t, param)
      def test(obj, foreign, latin):
        global printed_succeeded_failed
        if int(index) % 100 == 0:
          if not printed_succeeded_failed:
            printed_succeeded_failed = True
            show_failure(pagemsg, fa_translit.num_succeeded, fa_translit.num_failed)
        else:
          printed_succeeded_failed = False
        pagemsg("Processing %s" % unicode(obj.t))
        return fa_translit.test_with_obj(obj, latin, foreign, "matched")
      foreign = None
      latin = None
      if obj.param[0] == "separate":
        _, foreign, latin = obj.param
        foreign = getp(foreign)
        latin = getp(latin)
      elif obj.param[0] == "separate-pagetitle":
        _, foreign_dest, latin = obj.param
        foreign = pagetitle
        latin = getp(latin)
      elif obj.param[0] == "inline":
        _, foreign_param, foreign_mod, latin_mod, inline_mod = obj.param
        foreign = inline_mod.mainval if foreign_mod is None else inline_mod.get_modifier(foreign_mod)
        latin = inline_mod.get_modifier(latin_mod)
      obj.addl_params["no_vocalize"] = args.no_vocalize
      if not foreign or not latin or latin in ["-", "?"]:
        pagemsg("Skipped: foreign=%s, latin=%s" % (foreign, latin))
      else:
        latins = fa_translit.split_multiple_translits(latin, foreign)
        if latins is not None:
          # Since there are different vocalizations associated with different translits.
          obj.addl_params["no_vocalize"] = True
          for this_latin in latins:
            test(obj, foreign, this_latin)
        else:
          test(obj, foreign, latin)
    return blib.process_one_page_links(index, pagetitle, text, ["fa"], process_param,
        templates_seen, templates_changed)
  else:
    return canon_one_page_links(pagetitle, index, text, "fa", "fa-Arab", fa_translit,
        templates_seen, templates_changed, {"no_vocalize": args.no_vocalize})

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
  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
      skip_ignorable_pages=True)
# If in --test mode, we need to use the num_succeeded/num_failed from fa_translit as the ones in canon_foreign aren't
# set.
if args.test:
  show_failure(msg, fa_translit.num_succeeded, fa_translit.num_failed)
else:
  show_failure(msg)
blib.output_process_links_template_counts(templates_seen, templates_changed)
