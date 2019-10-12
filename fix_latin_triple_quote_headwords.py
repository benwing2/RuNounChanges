#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib

import find_regex

header_to_headword_form_template = {
  "Noun": "la-noun-form",
  "Verb": "la-verb-form",
  "Adjective": "la-adj-form",
  "Pronoun": "la-pronoun-form",
  "Proper noun": "la-proper noun-form",
}

def process_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
  if len(subsections) < 3:
    pagemsg("Something wrong, only one subsection")
    pagemsg("------- begin text --------")
    msg(text.rstrip('\n'))
    msg("------- end text --------")
    return
  for k in xrange(2, len(subsections), 2):
    m = re.search("^=+(.*?)=+$", subsections[k - 1].strip())
    header = m.group(1)
    def replace_triple_quote_header(m):
      headword = m.group(1)
      if header not in header_to_headword_form_template:
        pagemsg("WARNING: Can't replace triple-quote headword, header %s not recognized: %s" % (
          header, m.group(0)))
        return m.group(0)
      template = header_to_headword_form_template[header]
      if m.group(2):
        return "{{%s|%s|g=%s}}" % (template, headword, m.group(2))
      else:
        return "{{%s|%s}}" % (template, headword)

    subsections[k] = re.sub(r"^'''(.*?)'''(?: \{\{g\|([^{}|\n]*?)\}\})?$",
        replace_triple_quote_header, subsections[k], 0, re.M)

  text = "".join(subsections)
  pagemsg("------- begin text --------")
  msg(text.rstrip('\n'))
  msg("------- end text --------")

parser = blib.create_argparser("Fix raw Latin triple-quote headwords based on section header")
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = codecs.open(args.direcfile, "r", "utf-8")

pagename_and_text = find_regex.yield_text_from_find_regex(lines, args.verbose)
for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
    get_name=lambda x:x[0]):
  process_page(index, pagename, text)
