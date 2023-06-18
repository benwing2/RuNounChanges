#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Move text outside of {{RQ:Chapman Iliad}} inside, with some renaming of templates and args.
# Specifically, we replace:
#
# #* {{RQ:Chapman Iliad}}
# #*: Childish, unworthy '''dares''' / Are not enough to part our powers.
#
# with:
#
# #* {{RQ:Homer Chapman Iliads|passage=Childish, unworthy '''dares''' / Are not enough to part our powers.}}

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  curtext = text + "\n"

  def replace_chapman_iliad(m):
    template, text = m.groups()
    parsed = blib.parse_text(template)
    t = list(parsed.filter_templates())[0]
    if tname(t) != "RQ:Chapman Iliad":
      return m.group(0)
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    text = re.sub(r"^''(.*)''$", r"\1", text)
    t.add("passage", text)
    blib.set_template_name(t, "RQ:Homer Chapman Iliads")
    notes.append("reformat {{RQ:Chapman Iliad}} into {{RQ:Homer Chapman Iliads}}")
    return str(t) + "\n"

  curtext = re.sub(r"(\{\{RQ:Chapman Iliad.*?\}\})\n#+\*:\s*(.*?)\n",
      replace_chapman_iliad, curtext)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Reformat {{RQ:Chapman Iliad}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:RQ:Chapman Iliad"], edit=True, stdin=True)
