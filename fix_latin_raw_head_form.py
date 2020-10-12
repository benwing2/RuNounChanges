#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

pos_to_template = {
  "noun form": "la-noun-form",
  "noun forms": "la-noun-form",
  "proper noun form": "la-proper noun-form",
  "proper noun forms": "la-proper noun-form",
  "pronoun form": "la-pronoun-form",
  "pronoun forms": "la-pronoun-form",
  "verb form": "la-verb-form",
  "verb forms": "la-verb-form",
  "adjective form": "la-adj-form",
  "adjective forms": "la-adj-form",
  "participle form": "la-part-form",
  "participle forms": "la-part-form",
  "numeral form": "la-numeral-form",
  "numeral forms": "la-numeral-form",
  "suffix form": "la-suffix-form",
  "suffix forms": "la-suffix-form",
}

def process_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "head" and getparam(t, "1") == "la":
      pos = getparam(t, "2")
      if pos not in pos_to_template:
        pagemsg("WARNING: Saw unrecognized part of speech %s: %s" % (pos, unicode(t)))
        continue
      if getparam(t, "3") or getparam(t, "head"):
        pagemsg("WARNING: Saw 3= or head=: %s" % unicode(t))
        continue
      origt = unicode(t)
      t.add("1", pagename)
      blib.set_template_name(t, pos_to_template[pos])
      rmparam(t, "2")
      t.add("FIXME", "1")
      pagemsg("Replaced %s with %s" % (origt, unicode(t)))
  text = unicode(parsed)

  pagemsg("------- begin text --------")
  msg(text.rstrip('\n'))
  msg("------- end text --------")

parser = blib.create_argparser("Fix Latin raw-form {{head|la|... form}} usages")
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = codecs.open(args.direcfile, "r", "utf-8")

pagename_and_text = blib.yield_text_from_find_regex(lines, args.verbose)
for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
    get_name=lambda x:x[0]):
  process_page(index, pagename, text)
