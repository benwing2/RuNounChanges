#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

import push_find_regex_changes

def process_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  m = re.search(r"\A(.*?)(\n+--+\n*)\Z", text, re.S)
  if m:
    text, separator = m.groups(1)
  else:
    separator = ""

  def combine_text_separator(text, separator):
    if separator:
      return (text + separator).rstrip('\n') + '\n'
    else:
      return text.rstrip('\n')

  if "==Etymology 1==" in text:
    pagemsg("Already saw multiple etym sections")
    pagemsg("------- begin text --------")
    msg(combine_text_separator(text, separator))
    msg("------- end text --------")
    return

  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
  if len(subsections) < 3:
    pagemsg("WARNING: Something wrong, only one subsection")
    pagemsg("------- begin text --------")
    msg(combine_text_separator(text, separator))
    msg("------- end text --------")
    return

  def increase_indent(subsecs):
    new_subsecs = []
    for k in xrange(len(subsecs)):
      if k % 2 == 1:
        new_subsecs.append(re.sub("^(.*)\n$", r"=\1=\n", subsecs[k]))
      else:
        new_subsecs.append(subsecs[k])
    return new_subsecs

  etym_section = None
  if subsections[1] == "===Etymology===\n":
    etym_section = 1
  elif len(subsections) >= 4 and subsections[3] == "===Etymology===\n":
    etym_section = 3
  if etym_section:
    subsections = (
      subsections[0:1] +
      subsections[etym_section:etym_section + 2] +
      subsections[1:etym_section] +
      subsections[etym_section + 2:]
    )
    new_subsecs1 = re.sub("^====Etymology====$", "===Etymology 1===",
      "".join(increase_indent(subsections)), 0, re.M)
    new_subsecs2 = re.sub("^====Etymology====$", "===Etymology 2===",
      "".join(increase_indent(subsections)), 0, re.M)
    text = new_subsecs1.rstrip("\n") + "\n\n" + new_subsecs2.strip()
  else:
    new_subsecs1 = "".join(increase_indent(subsections))
    new_subsecs2 = "".join(increase_indent(subsections))
    text = ("\n===Etymology 1===\n\n" + new_subsecs1.strip() +
      "\n\n===Etymology 2===\n\n" + new_subsecs2.strip())

  pagemsg("------- begin text --------")
  msg(combine_text_separator(text, separator))
  msg("------- end text --------")

parser = blib.create_argparser("Double etym sections in find_regex.py output")
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = codecs.open(args.direcfile, "r", "utf-8")

pagename_and_text = push_find_regex_changes.yield_text(lines, args.verbose)
for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
    get_name=lambda x:x[0]):
  process_page(index, pagename, text)
