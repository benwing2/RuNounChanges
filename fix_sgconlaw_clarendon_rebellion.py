#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Move text outside of {{RQ:Clarendon Rebellion}} inside, with some renaming of templates and args. Specifically, we replace:
#
##* {{RQ:Clarendon Rebellion}}
##*: They discerned a body of five '''cornets''' of horse very full, standing in very good order to receive them.
#
# with:
#
##* {{RQ:Clarendon History|passage=They discerned a body of five '''cornets''' of horse very full, standing in very good order to receive them.}}

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, errmsg, site

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  curtext = text + "\n"

  def replace_clarendon_rebellion(m):
    template, text = m.groups()
    parsed = blib.parse_text(template)
    t = list(parsed.filter_templates())[0]
    if tname(t) != "RQ:Clarendon Rebellion":
      return m.group(0)
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    text = re.sub(r"^''(.*)''$", r"\1", text)
    t.add("passage", text)
    blib.set_template_name(t, "RQ:Clarendon History")
    notes.append("reformat {{RQ:Clarendon Rebellion}} into {{RQ:Clarendon History}}")
    return str(t) + "\n"

  curtext = re.sub(r"(\{\{RQ:Clarendon Rebellion.*?\}\})\n#+\*:\s*(.*?)\n",
      replace_clarendon_rebellion, curtext)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Reformat {{RQ:Clarendon Rebellion}}", include_pagefile=True,
    include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:RQ:Clarendon Rebellion"], edit=True, stdin=True)
