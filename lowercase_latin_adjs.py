#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

def process_page(index, pagename, text):
  pagename = pagename[0].lower() + pagename[1:]
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  if "==Etymology 1==" in text:
    pagemsg("WARNING: Saw Etymology 1, can't handle yet")
    pagemsg("------- begin text --------")
    msg(text.rstrip('\n'))
    msg("------- end text --------")
    return

  parsed = blib.parse_text(text)
  orig_headword = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["la-IPA", "la-adj", "la-adecl"]:
      param1 = getparam(t, "1")
      if param1:
        if tn == "la-adj":
          orig_headword = param1
        param1 = param1[0].lower() + param1[1:]
        origt = unicode(t)
        t.add("1", param1)
        pagemsg("Replacing %s with %s" % (origt, unicode(t)))
  text = unicode(parsed)

  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
  if len(subsections) < 3:
    pagemsg("Something wrong, only one subsection")
    pagemsg("------- begin text --------")
    msg(text.rstrip('\n'))
    msg("------- end text --------")
    return
  if orig_headword:
    alter_line = "* {{alter|la|%s||alternative case form}}" % orig_headword
    if "==Alternative forms==" in subsections[1]:
      subsections[2] = subsections[2].rstrip('\n') + "\n%s\n\n" % alter_line
    else:
      subsections[1:1] = [
        "===Alternative forms===\n",
        alter_line + "\n\n"
      ]

  text = "".join(subsections)
  pagemsg("------- begin text --------")
  msg(text.rstrip('\n'))
  msg("------- end text --------")

parser = blib.create_argparser("Lowercase adjectives from find_regex.py output")
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = codecs.open(args.direcfile, "r", "utf-8")

pagename_and_text = blib.yield_text_from_find_regex(lines, args.verbose)
for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
    get_name=lambda x:x[0]):
  process_page(index, pagename, text)
