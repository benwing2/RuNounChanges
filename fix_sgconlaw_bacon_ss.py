#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Move text outside of {{RQ:Bacon SS}} inside, with some renaming of templates and args.
# Specifically, we replace:
#
# #* {{RQ:Bacon SS}}
# #*: The [[cion]] [[overrule]]th the '''stock''' quite.
#
# with:
#
# #* {{RQ:Bacon Sylva Sylvarum|passage=The [[cion]] [[overrule]]th the '''stock''' quite.}}

import pywikibot, re, sys, codecs, argparse

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

  def replace_bacon_ss(m):
    template, text = m.groups()
    parsed = blib.parse_text(template)
    t = list(parsed.filter_templates())[0]
    if tname(t) != "RQ:Bacon SS":
      return m.group(0)
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    text = re.sub(r"^''(.*)''$", r"\1", text)
    t.add("passage", text)
    blib.set_template_name(t, "RQ:Bacon Sylva Sylvarum")
    notes.append("reformat {{RQ:Bacon SS}} into {{RQ:Bacon Sylva Sylvarum}}")
    return str(t) + "\n"

  curtext = re.sub(r"(\{\{RQ:Bacon SS.*?\}\})\n#+\*:\s*(.*?)\n",
      replace_bacon_ss, curtext)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Reformat {{RQ:Bacon SS}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:RQ:Bacon SS"], edit=True, stdin=True)
