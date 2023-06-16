#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Move text outside of {{RQ:Bacon The Advancement of Learning}} inside, with some renaming of templates and args. Specifically, we replace:
#
##* {{RQ:Bacon The Advancement of Learning}}
##*:'' '''Policying''' of cities.''
#
# with:
#
##* {{RQ:Bacon Learning|passage='''Policying''' of cities.}}

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  curtext = text + "\n"

  def replace_bacon_the_advancement_of_learning(m):
    template, text = m.groups()
    parsed = blib.parse_text(template)
    t = list(parsed.filter_templates())[0]
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    text = re.sub(r"^''(.*)''$", r"\1", text)
    t.add("passage", text)
    blib.set_template_name(t, "RQ:Bacon Learning")
    notes.append("reformat {{RQ:Bacon The Advancement of Learning}} into {{RQ:Bacon Learning}}")
    return str(t) + "\n"

  curtext = re.sub(r"(\{\{RQ:Bacon The Advancement of Learning\}\})\n#+\*:\s*(.*?)\n",
      replace_bacon_the_advancement_of_learning, curtext)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Reformat {{RQ:Bacon The Advancement of Learning}}", include_pagefile=True,
    include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:RQ:Bacon The Advancement of Learning"], edit=True, stdin=True)
