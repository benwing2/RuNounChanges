#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Move text outside of {{RQ:Dryden AZ}} inside, with some renaming of templates and args.
# Specifically, we replace:
#
# #* {{RQ:Dryden AZ}}
# #*: We are both love's captives, but with fates so '''cross''', / One must be happy by the other's loss.
#
# with:
#  
# #* {{RQ:Dryden Aureng-zebe|passage=We are both love's captives, but with fates so '''cross''', / One must be happy by the other's loss.}}

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  curtext = text + "\n"

  def replace_dryden_az(m):
    (text,) = m.groups()
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    notes.append("reformat {{RQ:Dryden AZ}} into {{RQ:Dryden Aureng-zebe}}")
    return "{{RQ:Dryden Aureng-zebe|passage=%s}}\n" % text

  curtext = re.sub(r"\{\{RQ:Dryden AZ\}\}\n#+\*: (.*?)\n",
      replace_dryden_az, curtext)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Reformat {{RQ:Dryden AZ}} and {{RQ:Dryden Aureng-zebe}}", include_pagefile=True,
    include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:RQ:Dryden AZ"], edit=True, stdin=True)
