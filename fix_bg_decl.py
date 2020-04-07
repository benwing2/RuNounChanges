#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

import find_regex

def process_page(index, pagename, text, adj):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  if "==Etymology 1==" in text or "==Pronunciation 1==" in text:
    pagemsg("WARNING: Saw Etymology/Pronunciation 1, can't handle yet")
    pagemsg("------- begin text --------")
    msg(text.rstrip('\n'))
    msg("------- end text --------")
    return

  parsed = blib.parse_text(text)
  headword = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in (adj and ["bg-adj"] or ["bg-noun", "bg-proper noun"]):
      headword = getparam(t, "1")
    if (tn == "bg-decl-adj" if adj else tn.startswith("bg-noun-")):
      origt = unicode(t)
      if not headword:
        pagemsg("WARNING: Saw %s without {{%s}} headword" % (origt, "bg-adj" if adj else "bg-noun"))
        continue
      del t.params[:]
      t.add("1", "%s<>" % headword)
      blib.set_template_name(t, "bg-adecl" if adj else "bg-ndecl")
      pagemsg("Replacing %s with %s" % (origt, unicode(t)))

  text = unicode(parsed)
  pagemsg("------- begin text --------")
  msg(text.rstrip('\n'))
  msg("------- end text --------")

parser = blib.create_argparser("Use {{bg-ndecl}}/{{bg-adecl}} for Bulgarian declensions")
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
parser.add_argument('--adj', help="Do adjectives instead of nouns", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = codecs.open(args.direcfile, "r", "utf-8")

pagename_and_text = find_regex.yield_text_from_find_regex(lines, args.verbose)
for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
    get_name=lambda x:x[0]):
  process_page(index, pagename, text, args.adj)
